import AppKit
import Carbon.HIToolbox

/// Registers system-wide hotkeys via Carbon so they fire even when Disleep has
/// no focus and without needing Accessibility permission.
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var handlerInstalled = false

    private static let signature: OSType = 0x44534C50 // 'DSLP'

    /// Bind (or clear) the hotkey for a given slot id. Re-registering the same
    /// id replaces the previous binding.
    func bind(id: UInt32, shortcut: Shortcut?, action: @escaping () -> Void) {
        installHandlerIfNeeded()

        if let existing = refs[id] {
            UnregisterEventHotKey(existing)
            refs[id] = nil
            actions[id] = nil
        }
        guard let shortcut else { return }

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: HotkeyManager.signature, id: id)
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        if status == noErr, let ref {
            refs[id] = ref
            actions[id] = action
        }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { mgr.actions[hkID.id]?() }
                return noErr
            },
            1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil
        )
    }
}
