import AppKit
import Carbon.HIToolbox

/// Thin wrapper around Carbon's RegisterEventHotKey for system-wide global shortcuts.
/// Works without special entitlements (unlike CGEvent taps which need Accessibility).
final class HotKey {
    private var ref: EventHotKeyRef?
    private let id: EventHotKeyID
    private let handler: () -> Void

    private static var registry: [UInt32: HotKey] = [:]
    private static var installed = false
    private static var counter: UInt32 = 0

    /// - Parameters:
    ///   - keyCode: a `kVK_*` virtual key code.
    ///   - modifiers: Carbon modifier mask (e.g. `UInt32(optionKey)`).
    init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        HotKey.counter += 1
        let signature = OSType(0x4F424F42) // 'OBOB'
        self.id = EventHotKeyID(signature: signature, id: HotKey.counter)
        self.handler = handler

        HotKey.installHandlerIfNeeded()

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr, let hotKeyRef else { return nil }
        self.ref = hotKeyRef
        HotKey.registry[id.id] = self
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        HotKey.registry[id.id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            if let hk = HotKey.registry[hkID.id] {
                DispatchQueue.main.async { hk.handler() }
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
