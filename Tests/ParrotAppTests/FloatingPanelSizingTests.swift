import Testing
import CoreGraphics
@testable import ParrotApp

private let sizingScreen = CGRect(x: 0, y: 0, width: 1440, height: 900)

@Test func automaticPanelGrowsToShowMultipleCompletedResults() {
    let current = CGRect(x: 120, y: 400, width: 560, height: 360)
    let fitted = FloatingPanelSizing.frame(
        current: current, desiredContentSize: CGSize(width: 760, height: 650),
        frameChrome: .zero, visibleFrame: sizingScreen,
        allowShrink: false, preservePosition: false
    )
    #expect(fitted.size == CGSize(width: 760, height: 650))
    #expect(fitted.minX == current.minX)
    #expect(fitted.maxY == current.maxY)
}

@Test func automaticPanelUsesScreenHeightBeforeNeedingDocumentScroll() {
    let fitted = FloatingPanelSizing.frame(
        current: CGRect(x: 300, y: 100, width: 560, height: 360),
        desiredContentSize: CGSize(width: 1000, height: 2200),
        frameChrome: CGSize(width: 0, height: 28), visibleFrame: sizingScreen,
        allowShrink: false, preservePosition: false
    )
    #expect(fitted.height == sizingScreen.height - 16)
    #expect(fitted.width <= 840)
    #expect(sizingScreen.insetBy(dx: 8, dy: 8).contains(fitted))
}

@Test func completedResultsDoNotShrinkDuringTheSameSizingSession() {
    let current = CGRect(x: 100, y: 92, width: 760, height: 700)
    let fitted = FloatingPanelSizing.frame(
        current: current, desiredContentSize: CGSize(width: 560, height: 350),
        frameChrome: .zero, visibleFrame: sizingScreen,
        allowShrink: false, preservePosition: false
    )
    #expect(fitted == current)
}

@Test func newSourceCanUseSmallerAutomaticSizeWithoutMovingUpperLeft() {
    let current = CGRect(x: 100, y: 92, width: 760, height: 700)
    let fitted = FloatingPanelSizing.frame(
        current: current, desiredContentSize: CGSize(width: 560, height: 340),
        frameChrome: .zero, visibleFrame: sizingScreen,
        allowShrink: true, preservePosition: true
    )
    #expect(fitted.size == CGSize(width: 560, height: 340))
    #expect(fitted.minX == current.minX)
    #expect(fitted.maxY == current.maxY)
}

@Test func manualResizeSurvivesNewSourceAndProviderUpdates() {
    let manuallyChosen = CGRect(x: 700, y: 200, width: 640, height: 560)
    for allowShrink in [false, true] {
        let fitted = FloatingPanelSizing.frame(
            current: manuallyChosen, desiredContentSize: CGSize(width: 840, height: 1400),
            frameChrome: .zero, visibleFrame: sizingScreen,
            allowShrink: allowShrink, preservePosition: true, userResized: true
        )
        #expect(fitted == manuallyChosen)
    }
}

@Test func movedOrPinnedPanelKeepsUpperLeftAndUsesAvailableRoom() {
    let current = CGRect(x: 800, y: 100, width: 560, height: 360)
    let fitted = FloatingPanelSizing.frame(
        current: current, desiredContentSize: CGSize(width: 840, height: 1400),
        frameChrome: .zero, visibleFrame: sizingScreen,
        allowShrink: false, preservePosition: true
    )
    #expect(fitted.minX == current.minX)
    #expect(fitted.maxY == current.maxY)
    #expect(fitted.maxX == sizingScreen.maxX - 8)
    #expect(fitted.minY == sizingScreen.minY + 8)
}

@Test func automaticSizingUsesTheCurrentScreenWithANegativeOrigin() {
    let screen = CGRect(x: -1600, y: -200, width: 1600, height: 1000)
    let fitted = FloatingPanelSizing.frame(
        current: CGRect(x: -1400, y: 200, width: 560, height: 360),
        desiredContentSize: CGSize(width: 760, height: 1800),
        frameChrome: .zero, visibleFrame: screen,
        allowShrink: false, preservePosition: false
    )
    #expect(screen.insetBy(dx: 8, dy: 8).contains(fitted))
    #expect(fitted.height == screen.height - 16)
}

@Test func movedPanelNearScreenEdgeDoesNotCollapseBelowItsCurrentSize() {
    let current = CGRect(x: 900, y: -30, width: 560, height: 360)
    let fitted = FloatingPanelSizing.frame(
        current: current, desiredContentSize: CGSize(width: 840, height: 1400),
        frameChrome: .zero, visibleFrame: sizingScreen,
        allowShrink: false, preservePosition: true
    )
    #expect(fitted.width >= current.width)
    #expect(fitted.height >= current.height)
    #expect(sizingScreen.insetBy(dx: 8, dy: 8).contains(fitted))
}

@Test func providerCountAndLongTextChooseAModerateReadingWidth() {
    #expect(FloatingPanelSizing.preferredWidth(longestTextCount: 20, providerCount: 1) == 560)
    #expect(FloatingPanelSizing.preferredWidth(longestTextCount: 20, providerCount: 2) == 660)
    #expect(FloatingPanelSizing.preferredWidth(longestTextCount: 500, providerCount: 1) == 760)
    #expect(FloatingPanelSizing.preferredWidth(longestTextCount: 1400, providerCount: 3) == 840)
}
