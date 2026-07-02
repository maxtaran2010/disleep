import AppKit
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
        if Settings.shared.syncRequiresActive {
            // NSAppleScript must run on the main thread.
            let active = ClaudeSync.claudeWorkingInITerm()
            guard Settings.shared.autoSyncEnabled else { return }
            AppController.shared.setSleep(disabled: active)
        } else {
            DispatchQueue.global().async {
                let active = ClaudeSync.claudeRunning()
                DispatchQueue.main.async {
                    guard Settings.shared.autoSyncEnabled else { return }
                    AppController.shared.setSleep(disabled: active)
                }
            }
        }
    }

    /// "Just running": is there any process literally named `claude` (any terminal)?
    private static func claudeRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["axo", "comm="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return false }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let out = String(data: data, encoding: .utf8) else { return false }
        for line in out.split(separator: "\n") {
            let comm = line.trimmingCharacters(in: .whitespaces)
            if (comm as NSString).lastPathComponent == "claude" { return true }
        }
        return false
    }

    /// "Actually working" (iTerm2 only). iTerm2 reports `jobName` as `node`
    /// (Claude Code is a Node app), so we can't match by name. Instead we take
    /// the ttys of sessions iTerm2 marks as "processing" (actively producing
    /// output) and intersect them with the ttys `ps` shows a `claude` process
    /// on. A non-empty intersection means a Claude session is actively working.
    /// Returns false if iTerm2 isn't running.
    private static func claudeWorkingInITerm() -> Bool {
        let running = NSWorkspace.shared.runningApplications
            .contains { $0.bundleIdentifier == "com.googlecode.iterm2" }
        guard running else { return false }

        let processingTTYs = itermProcessingTTYs()
        guard !processingTTYs.isEmpty else { return false }
        let claudeTTYs = claudeTTYs()
        return !processingTTYs.isDisjoint(with: claudeTTYs)
    }

    /// TTYs (e.g. "ttys006") of iTerm2 sessions currently processing output.
    private static func itermProcessingTTYs() -> Set<String> {
        let script = """
        tell application "iTerm2"
            set out to ""
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        set p to false
                        try
                            set p to is processing of s
                        end try
                        if p then
                            set tt to ""
                            try
                                tell s to set tt to tty
                            end try
                            set out to out & tt & " "
                        end if
                    end repeat
                end repeat
            end repeat
            return out
        end tell
        """
        var error: NSDictionary?
        guard let apple = NSAppleScript(source: script) else { return [] }
        let output = apple.executeAndReturnError(&error)
        if error != nil { return [] }
        let raw = output.stringValue ?? ""
        return Set(raw.split(whereSeparator: { $0 == " " || $0 == "\n" })
            .map { ($0 as NSString).lastPathComponent }) // "/dev/ttys006" → "ttys006"
    }

    /// TTYs a process literally named `claude` is attached to.
    private static func claudeTTYs() -> Set<String> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["axo", "tty=,comm="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let out = String(data: data, encoding: .utf8) else { return [] }

        var ttys = Set<String>()
        for line in out.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let sep = trimmed.firstIndex(of: " ") else { continue }
            let tty = String(trimmed[..<sep])
            let comm = trimmed[trimmed.index(after: sep)...].trimmingCharacters(in: .whitespaces)
            guard (comm as NSString).lastPathComponent == "claude" else { continue }
            guard tty != "??" else { continue } // process with no controlling terminal
            ttys.insert((tty as NSString).lastPathComponent)
        }
        return ttys
    }
}
