import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let panel = StatusPanelController()
    private var pulseTimer: Timer?
    private var pulseBright = true
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = Icons.idle
            button.target = self
            button.action = #selector(togglePanel)
        }

        AppController.shared.model.$sleepDisabled
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in self?.updateIcon(active: active) }
            .store(in: &cancellables)

        AppController.shared.bootstrap()
        Settings.shared.installHotkeys()
        ClaudeSync.shared.refresh()
        ReminderEngine.shared.refresh()
        ThermalWatch.shared.start()

        NotificationCenter.default.addObserver(
            forName: .disleepDismissPanel, object: nil, queue: .main
        ) { [weak self] _ in
            self?.panel.close()
        }

        // Menu bar apps have no window — reveal the panel once so it's clear where the app lives.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.showPanel()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return false
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }
        panel.toggle(from: button, model: AppController.shared.model)
    }

    private func showPanel() {
        guard let button = statusItem.button, !panel.isShown else { return }
        panel.show(from: button, model: AppController.shared.model)
    }

    private func updateIcon(active: Bool) {
        pulseTimer?.invalidate()
        pulseTimer = nil
        guard let button = statusItem.button else { return }
        if active {
            pulseBright = true
            button.image = Icons.activeBright
            button.toolTip = "Disleep — SLEEP IS DISABLED"
            pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
                guard let self, let button = self.statusItem.button else { return }
                self.pulseBright.toggle()
                button.image = self.pulseBright ? Icons.activeBright : Icons.activeDim
            }
        } else {
            button.image = Icons.idle
            button.toolTip = "Disleep — normal sleep"
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppController.shared.shutdown()
    }
}
