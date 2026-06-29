import AppKit
import AVFoundation
import ScreenCaptureKit

final class DemoScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private let queue = DispatchQueue(label: "parrot.demo.screen-recorder")
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var didStartSession = false
    private var lastSampleBuffer: CMSampleBuffer?
    private var stopTask: Task<Void, Never>?
    private var acceptedFrameCount = 0

    func start(outputPath: String, duration: TimeInterval, completion: @escaping @MainActor () -> Void) {
        stopTask?.cancel()
        stopTask = Task {
            do {
                try await startCapture(outputPath: outputPath)
                let nanoseconds = UInt64(max(1, duration) * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                try await stopCapture()
            } catch {
                DebugLog.log("demo-recorder: error=\(error.localizedDescription)")
            }
            await MainActor.run {
                completion()
            }
        }
    }

    private func startCapture(outputPath: String) async throws {
        if !CGPreflightScreenCaptureAccess() {
            DebugLog.log("demo-recorder: requesting screen recording permission")
            _ = CGRequestScreenCaptureAccess()
        }

        guard CGPreflightScreenCaptureAccess() else {
            throw NSError(
                domain: "ParrotDemoRecorder",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Screen recording permission is not granted"]
            )
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(
                domain: "ParrotDemoRecorder",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No display is available for recording"]
            )
        }

        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: outputURL)

        let displayBounds = CGDisplayBounds(display.displayID)
        let scale = Self.scaleFactor(for: display.displayID)
        let width = max(2, Int(displayBounds.width) * scale)
        let height = max(2, Int(displayBounds.height) * scale)

        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.queueDepth = 5
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true

        let writer = try AVAssetWriter(url: outputURL, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 12_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else {
            throw NSError(
                domain: "ParrotDemoRecorder",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to add video writer input"]
            )
        }
        writer.add(input)

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)

        self.writer = writer
        self.videoInput = input
        self.stream = stream
        self.didStartSession = false
        self.lastSampleBuffer = nil
        self.acceptedFrameCount = 0

        try await stream.startCapture()
        DebugLog.log("demo-recorder: started path=\(outputPath) display=\(display.displayID) size=\(width)x\(height)")
    }

    private func stopCapture() async throws {
        guard let stream else { return }
        try? await stream.stopCapture()

        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                guard self.didStartSession else {
                    self.writer?.cancelWriting()
                    self.stream = nil
                    self.writer = nil
                    self.videoInput = nil
                    self.lastSampleBuffer = nil
                    self.acceptedFrameCount = 0
                    DebugLog.log("demo-recorder: stopped without frames")
                    continuation.resume()
                    return
                }

                if let lastSampleBuffer, let videoInput, videoInput.isReadyForMoreMediaData {
                    videoInput.append(lastSampleBuffer)
                }
                videoInput?.markAsFinished()
                writer?.finishWriting { [weak self] in
                    let status = self?.writer?.status
                    let error = self?.writer?.error
                    self?.stream = nil
                    self?.writer = nil
                    self?.videoInput = nil
                    self?.lastSampleBuffer = nil
                    self?.didStartSession = false
                    self?.acceptedFrameCount = 0
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        DebugLog.log("demo-recorder: stopped status=\(String(describing: status))")
                        continuation.resume()
                    }
                }
            }
        }
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen, sampleBuffer.isValid else { return }

        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
           let attachment = attachments.first,
           let statusRaw = attachment[SCStreamFrameInfo.status] as? Int,
           let status = SCFrameStatus(rawValue: statusRaw),
           status != .complete {
            return
        }

        guard let writer, let videoInput, videoInput.isReadyForMoreMediaData else { return }
        if !didStartSession {
            guard writer.startWriting() else {
                DebugLog.log("demo-recorder: writer start failed error=\(writer.error?.localizedDescription ?? "unknown")")
                return
            }
            writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
            didStartSession = true
            DebugLog.log("demo-recorder: first frame ts=\(sampleBuffer.presentationTimeStamp.seconds)")
        }
        videoInput.append(sampleBuffer)
        lastSampleBuffer = sampleBuffer
        acceptedFrameCount += 1
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        DebugLog.log("demo-recorder: stream stopped error=\(error.localizedDescription)")
    }

    private static func scaleFactor(for displayId: CGDirectDisplayID) -> Int {
        guard let mode = CGDisplayCopyDisplayMode(displayId) else { return 1 }
        return max(1, mode.pixelWidth / max(1, mode.width))
    }
}
