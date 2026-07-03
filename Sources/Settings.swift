import Combine
import Foundation

/// Hotkey slot ids shared by Settings and HotkeyManager.
enum HotkeySlot: UInt32 {
    case toggle = 1
    case on = 2
    case off = 3
}

/// User-configurable settings, persisted to UserDefaults and applied live.
final class Settings: ObservableObject {
    static let shared = Settings()

    @Published var toggleShortcut: Shortcut? { didSet { persist(); rebind(.toggle) } }
    @Published var onShortcut: Shortcut? { didSet { persist(); rebind(.on) } }
    @Published var offShortcut: Shortcut? { didSet { persist(); rebind(.off) } }

    /// Automatically disable sleep while Claude Code is active, re-enable when idle.
    @Published var autoSyncEnabled: Bool { didSet { persist(); ClaudeSync.shared.refresh() } }
    /// true = require the session to be actively processing (iTerm2 only); false = just running.
    @Published var syncRequiresActive: Bool { didSet { persist(); ClaudeSync.shared.refresh() } }

    /// Playful periodic animation while sleep is disabled (.off = none).
    @Published var reminderStyle: ReminderStyle { didSet { persist(); ReminderEngine.shared.refresh() } }
    /// Seconds between reminder animations.
    @Published var reminderInterval: TimeInterval { didSet { persist(); ReminderEngine.shared.refresh() } }

    private let defaults = UserDefaults.standard
    private var loaded = false

    private init() {
        toggleShortcut = Settings.decode(defaults.data(forKey: "toggleShortcut"))
        onShortcut = Settings.decode(defaults.data(forKey: "onShortcut"))
        offShortcut = Settings.decode(defaults.data(forKey: "offShortcut"))
        autoSyncEnabled = defaults.bool(forKey: "autoSyncEnabled")
        syncRequiresActive = defaults.object(forKey: "syncRequiresActive") as? Bool ?? true
        reminderStyle = ReminderStyle(rawValue: defaults.string(forKey: "reminderStyle") ?? "") ?? .notch
        let interval = defaults.double(forKey: "reminderInterval")
        reminderInterval = interval > 0 ? interval : 60
        loaded = true
    }

    /// Register all hotkeys once at launch.
    func installHotkeys() {
        rebind(.toggle)
        rebind(.on)
        rebind(.off)
    }

    private func rebind(_ slot: HotkeySlot) {
        let shortcut: Shortcut?
        let action: () -> Void
        switch slot {
        case .toggle:
            shortcut = toggleShortcut
            action = { AppController.shared.toggle() }
        case .on:
            shortcut = onShortcut
            action = { AppController.shared.setSleepManually(disabled: true) }
        case .off:
            shortcut = offShortcut
            action = { AppController.shared.setSleepManually(disabled: false) }
        }
        HotkeyManager.shared.bind(id: slot.rawValue, shortcut: shortcut, action: action)
    }

    private func persist() {
        guard loaded else { return }
        defaults.set(Settings.encode(toggleShortcut), forKey: "toggleShortcut")
        defaults.set(Settings.encode(onShortcut), forKey: "onShortcut")
        defaults.set(Settings.encode(offShortcut), forKey: "offShortcut")
        defaults.set(autoSyncEnabled, forKey: "autoSyncEnabled")
        defaults.set(syncRequiresActive, forKey: "syncRequiresActive")
        defaults.set(reminderStyle.rawValue, forKey: "reminderStyle")
        defaults.set(reminderInterval, forKey: "reminderInterval")
    }

    private static func decode(_ data: Data?) -> Shortcut? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Shortcut.self, from: data)
    }

    private static func encode(_ shortcut: Shortcut?) -> Data? {
        guard let shortcut else { return nil }
        return try? JSONEncoder().encode(shortcut)
    }
}
