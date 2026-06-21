import Foundation
import ParrotCore
import ParrotEngines
import ParrotPlatform
import ParrotPlatformiOS
import ParrotSocial
import SwiftUI
import UIKit

@MainActor
final class IOSAppState: ObservableObject {
    @Published var activeSession: SocialTextSession?
    @Published var recentSessions: [SocialTextSession] = []
    @Published var isProcessing = false
    @Published var feedback: String?
    @Published var errorNotice: String?
    @Published var selectedTab: AppTab = .today
    @Published var clipboardSuggestionText: String?
    @Published var isQuickLensPresented = false
    @Published var quickLensStatus: QuickLensStatus = .idle
    @Published var quickLensNotice: String?

    enum AppTab: Hashable {
        case today
        case understand
        case express
        case history
        case settings
    }

    private let socialService: any SocialUnderstandingService & SocialExpressionService
    private let cleaner = OCRTextCleaner()
    private let ocr = IOSOCRService()
    private let clusterer = OCRTextBlockClusterer()
    private let latestScreenshotProvider = LatestScreenshotProvider()
    private let container = AppGroupContainer(identifier: "group.dev.parrot.shared")
    private lazy var sessionStore = AppGroupStoreFactory.socialSessionStore(container: container)
    private lazy var handoffStore = AppGroupStoreFactory.handoffStore(container: container)
    private let clipboard = IOSClipboardService()

    init() {
        let baseService = RuleBasedSocialService()
        if ProcessInfo.processInfo.arguments.contains("--ui-test-offline-social") {
            socialService = baseService
        } else {
            socialService = TranslationAugmentedSocialService(
                base: baseService,
                translationProvider: GoogleEngine()
            )
        }
    }

    func refreshClipboardSuggestion() {
        guard let text = clipboard.foregroundString()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              text.count < 4000 else {
            clipboardSuggestionText = nil
            showFeedback("No copied text")
            return
        }
        clipboardSuggestionText = text
    }

    func bootstrap() async {
        if configureUITestStateIfNeeded() {
            return
        }
        if consumePendingQuickLensRequest() {
            await openQuickLensFromLatestScreenshot()
            return
        }
        await consumeShareHandoff()
        await loadRecent()
        await purgeUnreferencedQuickLensImages()
        if activeSession == nil {
            openDemoSession()
        }
    }

    func handle(url: URL) async {
        guard url.scheme == "parrot" else { return }
        if url.host == "quick-lens" {
            await openQuickLensFromLatestScreenshot()
            return
        }
        await consumeShareHandoff()
    }

    func openDemoSession() {
        activeSession = SocialTextSession(
            origin: .manualInput,
            platform: .x,
            sourceDraft: "The product is not bad, but the onboarding feels like it was designed by people who already know how it works."
        )
        selectedTab = .understand
        Task { await understandActiveSession() }
    }

    private func configureUITestStateIfNeeded() -> Bool {
        let args = Set(ProcessInfo.processInfo.arguments)
        if args.contains("--ui-test-ocr") {
            activeSession = SocialTextSession(
                mode: .ocr,
                origin: .screenshot,
                platform: .reddit,
                sourceDraft: "@confused_user\n12:03 PM\nThis onboarding is not bad\nbut it collapses once real users touch it.\n\n"
            )
            recentSessions = []
            selectedTab = .understand
            return true
        }

        if args.contains("--ui-test-history") {
            var session = SocialTextSession(
                origin: .history,
                platform: .x,
                sourceDraft: "History seed: the roadmap sounds good, but onboarding is confusing."
            )
            session.apply(UnderstandResult(
                meaningSummary: "它在批评 roadmap 和真实 onboarding 之间的落差。",
                toneTags: ["product critique"],
                phraseExplanations: [PhraseExplanation(phrase: "roadmap", explanation: "Planning language.")],
                fullTranslation: "历史记录示例：路线图听起来不错，但新手引导很让人困惑。"
            ))
            activeSession = nil
            recentSessions = [session]
            selectedTab = .history
            return true
        }

        if args.contains("--ui-test-quick-lens-empty") {
            isQuickLensPresented = true
            quickLensStatus = .noRecentScreenshot
            quickLensNotice = "No recent screenshot found. Take a screenshot, then run Quick Lens again."
            selectedTab = .today
            return true
        }

        if args.contains("--ui-test-quick-lens-permission") {
            isQuickLensPresented = true
            quickLensStatus = .needsPermission
            quickLensNotice = "Parrot needs Photos access to find the screenshot you just took."
            selectedTab = .today
            return true
        }

        if args.contains("--ui-test-quick-lens") {
            configureQuickLensFixture()
            return true
        }

        return false
    }

    func openClipboardSuggestion() {
        guard let text = clipboardSuggestionText else { return }
        activeSession = SocialTextSession(origin: .clipboard, platform: .general, sourceDraft: text)
        selectedTab = .understand
        Task { await understandActiveSession() }
    }

    func openManualExpress() {
        var session = activeSession ?? SocialTextSession(origin: .manualInput, sourceDraft: "")
        session.switchToExpress()
        if session.userIntentDraft.isEmpty {
            session.userIntentDraft = "我觉得这个评价挺公平，产品不差，但是新用户第一次用确实会迷路。"
        }
        activeSession = session
        selectedTab = .express
    }

    func updateSourceDraft(_ text: String) {
        activeSession?.sourceDraft = text
        if activeSession?.quickLens != nil {
            activeSession?.quickLens?.selectedCandidateID = nil
        }
        activeSession?.updatedAt = Date()
    }

    func updateIntentDraft(_ text: String) {
        activeSession?.userIntentDraft = text
        activeSession?.updatedAt = Date()
    }

    func selectTone(_ tone: TonePreset) {
        activeSession?.selectedTone = tone
        activeSession?.updatedAt = Date()
    }

    func understandActiveSession() async {
        guard var session = activeSession else { return }
        isProcessing = true
        errorNotice = nil
        do {
            let result = try await socialService.understand(session: session)
            session.mode = .understand
            session.apply(result)
            activeSession = session
            try await sessionStore.save(session)
            await loadRecent()
        } catch {
            errorNotice = "Unable to explain this text. Edit the source and retry."
        }
        isProcessing = false
    }

    func generateReplies() async {
        guard var session = activeSession else { return }
        session.switchToExpress()
        isProcessing = true
        errorNotice = nil
        do {
            let result = try await socialService.generateReplies(session: session)
            session.apply(result)
            activeSession = session
            try await sessionStore.save(session)
            await loadRecent()
        } catch {
            errorNotice = "Unable to generate replies. Your draft is still here."
        }
        isProcessing = false
    }

    func refine(_ candidate: ReplyCandidate, action: RefinementAction) async {
        guard var session = activeSession else { return }
        do {
            let updated = try await socialService.refine(candidate: candidate, action: action, session: session)
            var candidates = session.express?.candidates ?? []
            if let index = candidates.firstIndex(where: { $0.id == candidate.id }) {
                candidates[index] = updated
            } else {
                candidates.insert(updated, at: 0)
            }
            session.express = ExpressResult(candidates: candidates)
            activeSession = session
            try await sessionStore.save(session)
            showFeedback("Refined")
        } catch {
            errorNotice = "Unable to refine this reply."
        }
    }

    func applyOCRCleanup(_ action: OCRCleanupAction) {
        guard var session = activeSession else { return }
        switch action {
        case .removeUsernames:
            session.sourceDraft = cleaner.removeUsernames(session.sourceDraft)
        case .removeTimestamps:
            session.sourceDraft = cleaner.removeTimestamps(session.sourceDraft)
        case .joinLines:
            session.sourceDraft = cleaner.joinBrokenLines(session.sourceDraft)
        case .deleteEmptyLines:
            session.sourceDraft = cleaner.deleteEmptyLines(session.sourceDraft)
        }
        activeSession = session
        showFeedback("OCR text cleaned")
    }

    func reopen(_ session: SocialTextSession) {
        activeSession = session
        if session.quickLens != nil {
            isQuickLensPresented = true
            quickLensStatus = .ready
            quickLensNotice = nil
        } else {
            selectedTab = session.mode == .express ? .express : .understand
        }
    }

    func setFavorite(_ session: SocialTextSession, _ value: Bool) async {
        try? await sessionStore.setFavorite(session.id, value)
        if activeSession?.id == session.id {
            activeSession?.isFavorite = value
        }
        await loadRecent()
    }

    func delete(_ session: SocialTextSession) async {
        try? await sessionStore.delete(session.id)
        if activeSession?.id == session.id {
            activeSession = nil
        }
        await loadRecent()
    }

    func activeOCRThumbnail() -> UIImage? {
        guard let fileName = activeSession?.sourceImageFileName else { return nil }
        return UIImage(contentsOfFile: container.handoffImageURL(fileName: fileName).path)
    }

    func activeQuickLensImage() -> UIImage? {
        guard let fileName = activeSession?.quickLens?.imageFileName ?? activeSession?.sourceImageFileName else {
            return nil
        }
        return UIImage(contentsOfFile: container.handoffImageURL(fileName: fileName).path)
    }

    func copy(_ text: String) {
        UIPasteboard.general.string = text
        showFeedback("Copied")
    }

    func copySourceDraft() {
        let text = activeSession?.sourceDraft.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return }
        copy(text)
    }

    func openQuickLensFromLatestScreenshot() async {
        isQuickLensPresented = true
        quickLensNotice = nil
        errorNotice = nil

        var status = latestScreenshotProvider.authorizationStatus()
        if status == .notDetermined {
            quickLensStatus = .requestingPhotoPermission
            status = await latestScreenshotProvider.requestAuthorization()
        }

        guard status == .authorized || status == .limited else {
            quickLensStatus = .needsPermission
            quickLensNotice = "Parrot needs Photos access to find the screenshot you just took. You can still share a screenshot to Parrot or type manually."
            return
        }

        quickLensStatus = .loadingScreenshot
        do {
            guard let asset = try await latestScreenshotProvider.latestScreenshot(maxAge: 60) else {
                quickLensStatus = .noRecentScreenshot
                quickLensNotice = "No screenshot from the last 60 seconds was found."
                return
            }
            let fileName = try persistQuickLensImage(asset.imageData)
            guard let image = UIImage(data: asset.imageData), let cgImage = image.cgImage else {
                quickLensStatus = .screenshotLoadFailed
                quickLensNotice = "The latest screenshot could not be loaded."
                return
            }
            await processQuickLensImage(
                fileName: fileName,
                image: cgImage,
                createdAt: asset.createdAt,
                pixelSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
                platform: .general
            )
        } catch ProviderError.auth {
            quickLensStatus = .needsPermission
            quickLensNotice = "Parrot needs Photos access to find the screenshot you just took."
        } catch {
            quickLensStatus = .screenshotLoadFailed
            quickLensNotice = "The latest screenshot could not be loaded. Try sharing the screenshot to Parrot instead."
        }
    }

    func selectQuickLensCandidate(_ candidateID: UUID) async {
        guard var session = activeSession,
              var lens = session.quickLens,
              let candidate = lens.selectCandidate(id: candidateID) else { return }

        session.quickLens = lens
        session.sourceDraft = candidate.text
        session.updatedAt = Date()
        activeSession = session
        await runQuickLensUnderstand()
    }

    func retryQuickLensOCR() async {
        guard let image = activeQuickLensImage(),
              let cgImage = image.cgImage,
              let lens = activeSession?.quickLens else {
            await openQuickLensFromLatestScreenshot()
            return
        }
        await processQuickLensImage(
            fileName: lens.imageFileName,
            image: cgImage,
            createdAt: lens.screenshotCreatedAt,
            pixelSize: lens.imagePixelSize.cgSize,
            platform: activeSession?.platform ?? .general
        )
    }

    func openQuickLensManualCrop() {
        quickLensNotice = "Drag across the screenshot to choose the exact text area, then use the crop."
    }

    func applyQuickLensCrop(_ rect: CGRectCodable) async {
        guard let image = activeQuickLensImage(),
              let cgImage = image.cgImage,
              var session = activeSession,
              var lens = session.quickLens else { return }

        let clamped = rect.clampedUnitRect.cgRect
        let pixelRect = CGRect(
            x: clamped.minX * CGFloat(cgImage.width),
            y: clamped.minY * CGFloat(cgImage.height),
            width: clamped.width * CGFloat(cgImage.width),
            height: clamped.height * CGFloat(cgImage.height)
        ).integral

        guard pixelRect.width > 8,
              pixelRect.height > 8,
              let cropped = cgImage.cropping(to: pixelRect) else {
            quickLensNotice = "Choose a larger crop area."
            return
        }

        quickLensStatus = .recognizingText
        do {
            let result = try await ocr.recognize(cropped)
            let text = result.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                quickLensStatus = .ocrFailed
                quickLensNotice = "No useful text was found in that crop."
                return
            }
            let candidate = QuickLensCandidate(
                text: text,
                boundingBox: CGRectCodable(clamped),
                lineBoxes: [CGRectCodable(clamped)],
                confidence: result.confidence,
                score: 100,
                roleHint: .primaryBody
            )
            lens.candidates = [candidate] + lens.candidates
            lens.selectedCandidateID = candidate.id
            lens.ocrConfidence = result.confidence
            session.quickLens = lens
            session.sourceDraft = text
            session.updatedAt = Date()
            activeSession = session
            await runQuickLensUnderstand()
        } catch {
            quickLensStatus = .ocrFailed
            quickLensNotice = "OCR could not read that crop. Try a larger area or edit the text manually."
        }
    }

    func editQuickLensSource() {
        quickLensNotice = "Edit the recognized source, then rerun Explain."
    }

    private func consumeShareHandoff() async {
        guard let handoff = try? await handoffStore.consumeLatest() else { return }
        var session = handoff.makeSession()
        activeSession = session
        selectedTab = .understand

        if handoff.kind == .image, let fileName = handoff.imageFileName {
            isProcessing = true
            do {
                let result = try await ocr.recognize(fileURL: container.handoffImageURL(fileName: fileName))
                session.sourceDraft = result.fullText
                session.mode = .ocr
                activeSession = session
                try await sessionStore.save(session)
                await loadRecent()
            } catch {
                errorNotice = "OCR could not read this image. The screenshot is preserved; you can type or paste the text manually."
            }
            isProcessing = false
        } else if handoff.kind == .text || handoff.kind == .url {
            await understandActiveSession()
        }
    }

    private func processQuickLensImage(
        fileName: String,
        image: CGImage,
        createdAt: Date,
        pixelSize: CGSize,
        platform: PlatformPreset
    ) async {
        quickLensStatus = .recognizingText
        quickLensNotice = nil

        do {
            let result = try await ocr.recognize(image)
            let candidates = clusterer.cluster(blocks: result.blocks, platform: platform)
            guard let selected = candidates.first(where: { !$0.isNoise }) ?? candidates.first else {
                var session = SocialTextSession(
                    mode: .understand,
                    origin: .latestScreenshot,
                    platform: platform,
                    sourceDraft: "",
                    sourceImageFileName: fileName,
                    quickLens: QuickLensState(
                        imageFileName: fileName,
                        imagePixelSize: CGSizeCodable(pixelSize),
                        screenshotCreatedAt: createdAt,
                        candidates: [],
                        ocrConfidence: result.confidence
                    )
                )
                session.updatedAt = Date()
                activeSession = session
                quickLensStatus = .ocrFailed
                quickLensNotice = "OCR ran, but no useful text block was found."
                return
            }

            let lens = QuickLensState(
                imageFileName: fileName,
                imagePixelSize: CGSizeCodable(pixelSize),
                screenshotCreatedAt: createdAt,
                candidates: candidates,
                selectedCandidateID: selected.id,
                ocrConfidence: result.confidence
            )
            activeSession = SocialTextSession(
                mode: .understand,
                origin: .latestScreenshot,
                platform: platform,
                sourceDraft: selected.text,
                sourceImageFileName: fileName,
                quickLens: lens
            )
            await runQuickLensUnderstand()
        } catch {
            quickLensStatus = .ocrFailed
            quickLensNotice = "OCR could not read this screenshot. Try crop, import, or manual input."
        }
    }

    private func runQuickLensUnderstand() async {
        guard var session = activeSession else { return }
        quickLensStatus = .translating
        isProcessing = true
        errorNotice = nil
        do {
            let result = try await socialService.understand(session: session)
            session.mode = .understand
            session.apply(result)
            activeSession = session
            try await sessionStore.save(session)
            await loadRecent()
            quickLensStatus = .ready
        } catch {
            errorNotice = "Unable to explain this text. Edit the source and retry."
            quickLensStatus = .ready
        }
        isProcessing = false
    }

    private func persistQuickLensImage(_ data: Data) throws -> String {
        let fileName = "HandoffImages/quick-lens-\(UUID().uuidString).png"
        let directory = container.handoffImagesDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: container.handoffImageURL(fileName: fileName), options: .atomic)
        return fileName
    }

    private func loadRecent() async {
        recentSessions = (try? await sessionStore.recent(limit: 20)) ?? []
    }

    private func consumePendingQuickLensRequest() -> Bool {
        QuickLensLaunchRequest.consume(maxAge: 120)
    }

    private func purgeUnreferencedQuickLensImages() async {
        let sessions = (try? await sessionStore.recent(limit: 5000)) ?? []
        let referenced = Set(
            sessions.compactMap(\.sourceImageFileName)
                + [activeSession?.sourceImageFileName].compactMap { $0 }
        )
        let directory = container.handoffImagesDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        for file in files {
            let relativeName = "HandoffImages/\(file.lastPathComponent)"
            guard !referenced.contains(relativeName) else { continue }
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if modified < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private func configureQuickLensFixture() {
        let fileName = "HandoffImages/quick-lens-fixture.png"
        let image = makeQuickLensFixtureImage()
        if let data = image.pngData() {
            try? FileManager.default.createDirectory(at: container.handoffImagesDirectory, withIntermediateDirectories: true)
            try? data.write(to: container.handoffImageURL(fileName: fileName), options: .atomic)
        }

        let main = QuickLensCandidate(
            text: "The product is useful, but the onboarding asks too much too early.",
            boundingBox: CGRectCodable(x: 0.12, y: 0.23, width: 0.76, height: 0.17),
            lineBoxes: [
                CGRectCodable(x: 0.12, y: 0.23, width: 0.55, height: 0.04),
                CGRectCodable(x: 0.12, y: 0.29, width: 0.76, height: 0.04)
            ],
            confidence: 0.95,
            score: 92,
            roleHint: .primaryBody
        )
        let quote = QuickLensCandidate(
            text: "Quote: ship the feature first and fix onboarding later.",
            boundingBox: CGRectCodable(x: 0.16, y: 0.52, width: 0.68, height: 0.12),
            lineBoxes: [CGRectCodable(x: 0.16, y: 0.52, width: 0.68, height: 0.05)],
            confidence: 0.91,
            score: 64,
            roleHint: .quote
        )
        let lens = QuickLensState(
            imageFileName: fileName,
            imagePixelSize: CGSizeCodable(width: 390, height: 760),
            screenshotCreatedAt: Date(),
            candidates: [main, quote],
            selectedCandidateID: main.id,
            ocrConfidence: 0.94
        )
        var session = SocialTextSession(
            origin: .latestScreenshot,
            platform: .x,
            sourceDraft: main.text,
            sourceImageFileName: fileName,
            quickLens: lens
        )
        session.apply(UnderstandResult(
            meaningSummary: "它在说产品有价值，但新手引导太早要求用户理解太多东西。",
            toneTags: ["product critique", "constructive"],
            phraseExplanations: [
                PhraseExplanation(phrase: "asks too much too early", explanation: "新用户还没建立上下文时就被要求做太多决定。")
            ],
            fullTranslation: "这个产品有用，但 onboarding 太早向用户索取太多。"
        ))
        activeSession = session
        selectedTab = .today
        isQuickLensPresented = true
        quickLensStatus = .ready
        quickLensNotice = nil
    }

    private func makeQuickLensFixtureImage() -> UIImage {
        let size = CGSize(width: 390, height: 760)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0.96, green: 0.965, blue: 0.94, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let card = CGRect(x: 28, y: 118, width: 334, height: 198)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: card, cornerRadius: 18).fill()
            UIColor.darkGray.setFill()
            "@productperson".draw(at: CGPoint(x: 48, y: 138), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14)])
            "The product is useful,".draw(at: CGPoint(x: 48, y: 176), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
            "but the onboarding asks too much".draw(at: CGPoint(x: 48, y: 208), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
            "too early.".draw(at: CGPoint(x: 48, y: 240), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])

            let quote = CGRect(x: 48, y: 395, width: 292, height: 108)
            UIColor(red: 0.91, green: 0.96, blue: 1, alpha: 1).setFill()
            UIBezierPath(roundedRect: quote, cornerRadius: 14).fill()
            UIColor.darkGray.setFill()
            "Quote: ship the feature first".draw(at: CGPoint(x: 66, y: 422), withAttributes: [.font: UIFont.systemFont(ofSize: 16)])
            "and fix onboarding later.".draw(at: CGPoint(x: 66, y: 452), withAttributes: [.font: UIFont.systemFont(ofSize: 16)])
        }
    }

    private func showFeedback(_ text: String) {
        feedback = text
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                if self?.feedback == text { self?.feedback = nil }
            }
        }
    }
}

enum QuickLensStatus: Equatable {
    case idle
    case requestingPhotoPermission
    case loadingScreenshot
    case recognizingText
    case translating
    case ready
    case needsPermission
    case noRecentScreenshot
    case ocrFailed
    case screenshotLoadFailed

    var title: String {
        switch self {
        case .idle: return "Quick Lens"
        case .requestingPhotoPermission: return "Requesting Photos access"
        case .loadingScreenshot: return "Loading latest screenshot"
        case .recognizingText: return "Finding text blocks"
        case .translating: return "Explaining selected text"
        case .ready: return "Quick Lens"
        case .needsPermission: return "Photos access needed"
        case .noRecentScreenshot: return "No recent screenshot"
        case .ocrFailed: return "Text not found"
        case .screenshotLoadFailed: return "Screenshot unavailable"
        }
    }

    var isRecoverableFailure: Bool {
        switch self {
        case .needsPermission, .noRecentScreenshot, .ocrFailed, .screenshotLoadFailed:
            return true
        case .idle, .requestingPhotoPermission, .loadingScreenshot, .recognizingText, .translating, .ready:
            return false
        }
    }
}

enum QuickLensLaunchRequest {
    static let suiteName = "group.dev.parrot.shared"
    static let key = "quickLensRequestedAt"

    static func markRequested(at date: Date = Date()) {
        for store in stores {
            store.set(date.timeIntervalSince1970, forKey: key)
        }
    }

    static func consume(maxAge: TimeInterval, now: Date = Date()) -> Bool {
        var hasFreshRequest = false
        for store in stores {
            guard let timestamp = store.object(forKey: key) as? TimeInterval else {
                continue
            }
            store.removeObject(forKey: key)
            if now.timeIntervalSince1970 - timestamp < maxAge {
                hasFreshRequest = true
            }
        }
        return hasFreshRequest
    }

    private static var stores: [UserDefaults] {
        var result = [UserDefaults.standard]
        if let suite = UserDefaults(suiteName: suiteName) {
            result.append(suite)
        }
        return result
    }
}

enum OCRCleanupAction: CaseIterable {
    case removeUsernames
    case removeTimestamps
    case joinLines
    case deleteEmptyLines

    var title: String {
        switch self {
        case .removeUsernames: return "Remove usernames"
        case .removeTimestamps: return "Remove timestamps"
        case .joinLines: return "Join lines"
        case .deleteEmptyLines: return "Delete empty lines"
        }
    }
}
