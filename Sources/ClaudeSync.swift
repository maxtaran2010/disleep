import Foundation

/// Watches for running/active Claude Code CLI processes and drives sleep state:
/// active → sleep disabled, idle → sleep enabled.
final class ClaudeSync {
    static let shared = ClaudeSync()

    private var timer: Timer?
    private let interval: TimeInterval = 4

    /// Start or stop polling to match the current setting.
    func refresh() {
        timer?.invalidate()
        timer = nil
        guard Settings.shared.autoSyncEnabled else { return }
        poll()
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func poll() {
        let requireActive = Settings.shared.syncRequiresActive
        let threshold = Settings.shared.cpuThreshold
        DispatchQueue.global().async {
            let active = ClaudeSync.claudeActive(requireActive: requireActive, threshold: threshold)
            DispatchQueue.main.async {
                guard Settings.shared.autoSyncEnabled else { return }
                AppController.shared.setSleep(disabled: active)
            }
        }
    }

    /// Is there a Claude Code process that counts as "on" under the current rule?
    private static func claudeActive(requireActive: Bool, threshold: Double) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["axo", "pcpu=,comm="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return false }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let out = String(data: data, encoding: .utf8) else { return false }

        for line in out.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let sep = trimmed.firstIndex(of: " ") else { continue }
            let cpuStr = trimmed[..<sep]
            let comm = trimmed[trimmed.index(after: sep)...].trimmingCharacters(in: .whitespaces)
            // comm is the full executable path; match a process literally named "claude"
            guard (comm as NSString).lastPathComponent == "claude" else { continue }
            if !requireActive { return true }
            // ps may localize the decimal separator (e.g. "7,2"); normalize to a dot.
            let normalized = cpuStr.replacingOccurrences(of: ",", with: ".")
            if let cpu = Double(normalized), cpu >= threshold { return true }
        }
        return false
    }
}
