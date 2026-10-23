import AppKit
import Carbon.HIToolbox
import TwoByFourKit

/// A system-wide keyboard shortcut via Carbon's RegisterEventHotKey, which
/// needs no Accessibility permission.
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    /// ⌃⌥Space.
    static let defaultKeyCode = UInt32(kVK_Space)
    static let defaultModifiers = UInt32(controlKey | optionKey)
    static let defaultLabel = "⌃⌥Space"

    init?(keyCode: UInt32 = HotKey.defaultKeyCode, modifiers: UInt32 = HotKey.defaultModifiers,
          action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return noErr }
            Unmanaged<HotKey>.fromOpaque(data).takeUnretainedValue().action()
            return noErr
        }, 1, &spec, me, &handler)
        let id = EventHotKeyID(signature: OSType(0x3278_3420), id: 1) // "2x4 "
        let registered = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
        guard installed == noErr, registered == noErr else {
            Log.shared.write("couldn't register the global shortcut \(HotKey.defaultLabel) (\(installed), \(registered))")
            return nil
        }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
