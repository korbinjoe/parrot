import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

extension CGImage {
    func parrotPNGData() -> Data? {
        #if canImport(AppKit)
        let rep = NSBitmapImageRep(cgImage: self)
        return rep.representation(using: .png, properties: [:])
        #elseif canImport(UIKit)
        return UIImage(cgImage: self).pngData()
        #else
        return nil
        #endif
    }

    func parrotJPEGData(compressionQuality: CGFloat = 0.8) -> Data? {
        #if canImport(AppKit)
        let rep = NSBitmapImageRep(cgImage: self)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        #elseif canImport(UIKit)
        return UIImage(cgImage: self).jpegData(compressionQuality: compressionQuality)
        #else
        return nil
        #endif
    }

    func parrotJPEGBase64(compressionQuality: CGFloat = 0.8) -> String? {
        parrotJPEGData(compressionQuality: compressionQuality)?.base64EncodedString()
    }
}
