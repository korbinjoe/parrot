import Foundation

#if canImport(UIKit)
import UIKit
#endif

public struct IOSClipboardService: Sendable {
    public init() {}

    public func foregroundString() -> String? {
        #if canImport(UIKit)
        UIPasteboard.general.string
        #else
        nil
        #endif
    }
}
