import AppKit
import SwiftUI

/// Owns the single Settings window. Menu bar apps have no windows by default,
/// so we build and focus one on demand.
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let host = NSHostingController(rootView: SettingsView(settings: Settings.shared))
        let win = NSWindow(contentViewController: host)
        win.title = "Disleep Settings"
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.isReleasedWhenClosed = false
        win.center()
        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            section("Keyboard Shortcuts") {
                shortcutRow("Toggle sleep", binding: $settings.toggleShortcut)
                shortcutRow("Turn sleep off (stay awake)", binding: $settings.onShortcut)
                shortcutRow("Turn sleep on (normal)", binding: $settings.offShortcut)
            }

            Divider()

            section("Claude Code Sync") {
                Toggle(isOn: $settings.autoSyncEnabled) {
                    Text("Follow Claude Code automatically")
                        .font(.system(size: 12, weight: .medium))
                }
                .toggleStyle(.switch)
                .tint(.orange)

                Text("Disables sleep while Claude Code is active and restores normal sleep when it stops.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("Trigger", selection: $settings.syncRequiresActive) {
                    Text("Only when actually working (iTerm2 only)").tag(true)
                    Text("Whenever it's running").tag(false)
                }
                .pickerStyle(.radioGroup)
                .disabled(!settings.autoSyncEnabled)

                if settings.syncRequiresActive {
                    Label("Uses the iTerm2 API to detect a busy Claude session. You'll be asked to allow Disleep to control iTerm2 once.",
                          systemImage: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 2)
                }
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            content()
        }
    }

    private func shortcutRow(_ label: String, binding: Binding<Shortcut?>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            ShortcutField(shortcut: binding)
        }
    }
}

/// Holds the transient recording state and the local key monitor.
final class ShortcutRecorder: ObservableObject {
    @Published var recording = false
    private var monitor: Any?
    var onCapture: ((Shortcut) -> Void)?

    func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // Esc cancels
                self.stop()
                return nil
            }
            if let s = Shortcut(event: event) {
                self.onCapture?(s)
                self.stop()
            }
            return nil // swallow the key while recording
        }
    }

    func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

/// Click to record a global shortcut. Captures the next key press via a local
/// event monitor; Esc cancels, the × button clears.
struct ShortcutField: View {
    @Binding var shortcut: Shortcut?
    @StateObject private var recorder = ShortcutRecorder()

    var body: some View {
        HStack(spacing: 6) {
            Button {
                if recorder.recording {
                    recorder.stop()
                } else {
                    recorder.onCapture = { shortcut = $0 }
                    recorder.start()
                }
            } label: {
                Text(recorder.recording ? "Type shortcut…" : (shortcut?.displayString ?? "Record"))
                    .font(.system(size: 12, weight: .medium).monospaced())
                    .frame(minWidth: 96)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(recorder.recording ? Color.orange.opacity(0.20) : Color.primary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(recorder.recording ? Color.orange : Color.clear)
                    )
            }
            .buttonStyle(.plain)

            if shortcut != nil {
                Button {
                    shortcut = nil
                    recorder.stop()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .onDisappear { recorder.stop() }
    }
}
