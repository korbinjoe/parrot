import AppKit
import Vision

/// Interactive region screenshot + Vision OCR.
/// Uses the system `screencapture -i` tool for reliable crosshair region selection,
/// then runs `VNRecognizeTextRequest` (offline, free) on the captured image.
enum ScreenOCR {

    enum OCRError: Error { case captureCancelled, noImage, recognitionFailed }

    /// Present the system region selector and OCR the result. Returns layout-ordered text.
    static func captureAndRecognize(languages: [String] = ["zh-Hans", "en-US"]) async throws -> String {
        let image = try await interactiveCapture()
        return try recognize(image, languages: languages)
    }

    /// Like `captureAndRecognize` but keeps the layout-ordered lines separate, so the caller can
    /// present a per-line picker. Empty lines are dropped.
    static func captureAndRecognizeLines(languages: [String] = ["zh-Hans", "en-US"]) async throws -> [String] {
        let image = try await interactiveCapture()
        return try recognizeLines(image, languages: languages)
    }

    /// Run `screencapture -i` to a temp file and load it as a CGImage.
    private static func interactiveCapture() async throws -> CGImage {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("parrot-ocr-\(UUID().uuidString).png")

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            proc.arguments = ["-i", "-x", tmp.path] // interactive, no sound
            proc.terminationHandler = { _ in cont.resume() }
            do { try proc.run() } catch { cont.resume(throwing: error) }
        }

        guard FileManager.default.fileExists(atPath: tmp.path),
              let nsImage = NSImage(contentsOf: tmp),
              let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.captureCancelled // user pressed Esc -> no file written
        }
        try? FileManager.default.removeItem(at: tmp)
        return cg
    }

    /// Vision text recognition with layout-aware ordering (top→bottom, left→right).
    static func recognize(_ image: CGImage, languages: [String]) throws -> String {
        try recognizeLines(image, languages: languages).joined(separator: "\n")
    }

    /// Layout-ordered recognized lines (top→bottom, left→right). Drops empties.
    static func recognizeLines(_ image: CGImage, languages: [String]) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results else { throw OCRError.recognitionFailed }

        let lines = observations.compactMap { obs -> (CGRect, String)? in
            guard let top = obs.topCandidates(1).first else { return nil }
            return (obs.boundingBox, top.string)
        }
        // Vision's origin is bottom-left; sort by descending Y (top first), then ascending X.
        let ordered = lines.sorted { a, b in
            if abs(a.0.origin.y - b.0.origin.y) > 0.02 {
                return a.0.origin.y > b.0.origin.y
            }
            return a.0.origin.x < b.0.origin.x
        }
        return ordered.map { $0.1 }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
