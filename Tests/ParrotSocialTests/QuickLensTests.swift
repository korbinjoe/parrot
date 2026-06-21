import CoreGraphics
import Foundation
import ParrotCore
import ParrotPlatformiOS
import Testing
@testable import ParrotSocial

private struct FakeLatestScreenshotProvider: LatestScreenshotProviding {
    var status: PhotoAccessStatus
    var asset: LatestScreenshotAsset?

    func authorizationStatus() -> PhotoAccessStatus { status }

    func requestAuthorization() async -> PhotoAccessStatus { status }

    func latestScreenshot(maxAge: TimeInterval) async throws -> LatestScreenshotAsset? {
        if status == .denied || status == .restricted {
            throw ProviderError.auth
        }
        return asset
    }
}

@Test func quickLensStateSelectsCandidateAndCodableRoundTrips() throws {
    let first = QuickLensCandidate(
        text: "Username",
        boundingBox: CGRectCodable(x: 0.1, y: 0.1, width: 0.3, height: 0.04),
        lineBoxes: [],
        confidence: 0.8,
        score: 2,
        roleHint: .username,
        isNoise: true
    )
    let second = QuickLensCandidate(
        text: "This is the actual post body.",
        boundingBox: CGRectCodable(x: 0.1, y: 0.2, width: 0.8, height: 0.12),
        lineBoxes: [],
        confidence: 0.93,
        score: 50,
        roleHint: .primaryBody
    )
    var state = QuickLensState(
        imageFileName: "HandoffImages/sample.png",
        imagePixelSize: CGSizeCodable(width: 1170, height: 2532),
        screenshotCreatedAt: Date(timeIntervalSince1970: 1_000),
        candidates: [first, second],
        ocrConfidence: 0.91
    )

    let selected = state.selectCandidate(id: second.id)
    let data = try JSONEncoder().encode(state)
    let decoded = try JSONDecoder().decode(QuickLensState.self, from: data)

    #expect(selected?.text == second.text)
    #expect(decoded.selectedCandidate?.text == second.text)
}

@Test func quickLensSessionStoresSelectedCandidateAsEditableSource() {
    let candidate = QuickLensCandidate(
        text: "Actual selected body text.",
        boundingBox: CGRectCodable(x: 0.15, y: 0.22, width: 0.7, height: 0.18),
        lineBoxes: [],
        confidence: 0.95,
        score: 80,
        roleHint: .primaryBody
    )
    let lens = QuickLensState(
        imageFileName: "HandoffImages/sample.png",
        imagePixelSize: CGSizeCodable(width: 1170, height: 2532),
        screenshotCreatedAt: Date(),
        candidates: [candidate],
        selectedCandidateID: candidate.id,
        ocrConfidence: 0.95
    )
    let session = SocialTextSession(
        origin: .latestScreenshot,
        sourceDraft: candidate.text,
        sourceImageFileName: lens.imageFileName,
        quickLens: lens
    )

    #expect(session.origin == .latestScreenshot)
    #expect(session.sourceDraft == "Actual selected body text.")
    #expect(session.quickLens?.selectedCandidate?.id == candidate.id)
}

@Test func latestScreenshotSelectorPicksNewestRecentScreenshotOnly() {
    let now = Date(timeIntervalSince1970: 1_000)
    let selector = LatestScreenshotSelector()
    let candidates = [
        LatestScreenshotCandidate(
            localIdentifier: "old-screenshot",
            createdAt: now.addingTimeInterval(-120),
            isScreenshot: true,
            pixelWidth: 100,
            pixelHeight: 200
        ),
        LatestScreenshotCandidate(
            localIdentifier: "new-non-screenshot",
            createdAt: now.addingTimeInterval(-5),
            isScreenshot: false,
            pixelWidth: 100,
            pixelHeight: 200
        ),
        LatestScreenshotCandidate(
            localIdentifier: "new-screenshot",
            createdAt: now.addingTimeInterval(-10),
            isScreenshot: true,
            pixelWidth: 100,
            pixelHeight: 200
        )
    ]

    let selected = selector.select(from: candidates, now: now, maxAge: 60)

    #expect(selected?.localIdentifier == "new-screenshot")
}

@Test func fakeLatestScreenshotProviderModelsPermissionFailure() async {
    let provider = FakeLatestScreenshotProvider(status: .denied, asset: nil)

    do {
        _ = try await provider.latestScreenshot(maxAge: 60)
        Issue.record("Expected auth error")
    } catch {
        #expect((error as? ProviderError) == .auth)
    }
}

@Test func clustererRanksSocialBodyAboveMetadata() {
    let blocks = [
        OCRBlock(text: "9:41", boundingBox: visionRect(x: 0.05, y: 0.94, width: 0.09, height: 0.025), confidence: 0.99),
        OCRBlock(text: "@productperson", boundingBox: visionRect(x: 0.11, y: 0.84, width: 0.28, height: 0.03), confidence: 0.96),
        OCRBlock(text: "The product is useful,", boundingBox: visionRect(x: 0.11, y: 0.77, width: 0.58, height: 0.035), confidence: 0.97),
        OCRBlock(text: "but the onboarding asks too much too early.", boundingBox: visionRect(x: 0.11, y: 0.72, width: 0.78, height: 0.035), confidence: 0.94),
        OCRBlock(text: "48 replies", boundingBox: visionRect(x: 0.12, y: 0.64, width: 0.16, height: 0.025), confidence: 0.92),
        OCRBlock(text: "Home", boundingBox: visionRect(x: 0.08, y: 0.04, width: 0.12, height: 0.03), confidence: 0.99)
    ]

    let candidates = OCRTextBlockClusterer().cluster(blocks: blocks, platform: .x)
    let first = candidates.first

    #expect(first?.text.contains("The product is useful") == true)
    #expect(first?.text.contains("@productperson") == false)
    #expect(first?.text.contains("Home") == false)
    #expect(first?.isNoise == false)
}

@Test func clustererKeepsLowConfidenceBodyEditable() {
    let blocks = [
        OCRBlock(text: "This blurry quote still matters", boundingBox: visionRect(x: 0.12, y: 0.48, width: 0.72, height: 0.04), confidence: 0.42),
        OCRBlock(text: "because the reply depends on it.", boundingBox: visionRect(x: 0.12, y: 0.43, width: 0.7, height: 0.04), confidence: 0.46)
    ]

    let candidates = OCRTextBlockClusterer().cluster(blocks: blocks, platform: .reddit)

    #expect(candidates.first?.text.contains("blurry quote") == true)
    #expect((candidates.first?.confidence ?? 1) < 0.5)
}

private func visionRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
    CGRect(x: x, y: y, width: width, height: height)
}
