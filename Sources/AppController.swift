import AppKit
import Combine

final class AppModel: ObservableObject {
    @Published var sleepDisabled = false
    @Published var authorized = false
    @Published var busy = false
}

final class AppController {
    static let shared = AppController()
    let model = AppModel()
    private var watchdogSpawned = false

    func bootstrap() {
        model.sleepDisabled = Sudo.systemSleepDisabled()
        ensureAuthorized { _ in }
    }

    func ensureAuthorized(_ completion: @escaping (Bool) -> Void) {
        if model.authorized { completion(true); return }
        model.busy = true
        DispatchQueue.global().async {
            var ok = Sudo.isAuthorized()
            if !ok {
                ok = Sudo.installRule() && Sudo.isAuthorized()
            }
            DispatchQueue.main.async {
                self.model.authorized = ok
                self.model.busy = false
                if ok, !self.watchdogSpawned {
                    Sudo.spawnWatchdog()
                    self.watchdogSpawned = true
                }
                completion(ok)
            }
        }
    }

    func toggle() {
        apply(target: !model.sleepDisabled)
    }

    /// Force a specific state (used by hotkeys "on"/"off" and by Claude sync).
    /// No-op if already there so we don't flash the HUD needlessly.
    func setSleep(disabled: Bool) {
        guard disabled != model.sleepDisabled else { return }
        apply(target: disabled)
    }

    private func apply(target: Bool) {
        guard !model.busy else { return }
        ensureAuthorized { ok in
            guard ok else { return }
            self.model.busy = true
            self.model.sleepDisabled = target
            HUD.show(sleepDisabled: target)
            DispatchQueue.global().async {
                Sudo.setSleepDisabled(target)
                let actual = Sudo.systemSleepDisabled()
                DispatchQueue.main.async {
                    self.model.busy = false
                    if actual != target {
                        self.model.sleepDisabled = actual
                        HUD.show(sleepDisabled: actual)
                    }
                }
            }
        }
    }

    func shutdown() {
        if model.authorized {
            Sudo.setSleepDisabled(false)
        }
    }
}
