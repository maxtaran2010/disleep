import AppKit

/// Privileged operations. A one-time sudoers drop-in makes
/// `sudo -n pmset -a disablesleep 0|1` passwordless; everything else runs as the user.
enum Sudo {
    static let pmsetPath = "/usr/bin/pmset"
    static let sudoersFile = "/etc/sudoers.d/disleep"

    // MARK: - Authorization

    static func isAuthorized() -> Bool {
        run("/usr/bin/sudo", ["-n", "-l", pmsetPath, "-a", "disablesleep", "1"]).status == 0
    }

    /// One admin password prompt. Writes the rule to a temp file, validates it with
    /// `visudo -c`, and only then installs it — a malformed rule can never break sudo.
    static func installRule() -> Bool {
        let user = NSUserName()
        let rule = "\(user) ALL=(root) NOPASSWD: \(pmsetPath) -a disablesleep 0, \(pmsetPath) -a disablesleep 1"
        let cmd = [
            "tmp=$(/usr/bin/mktemp)",
            "/usr/bin/printf '%s\\n' '\(rule)' > \"$tmp\"",
            "/usr/sbin/visudo -c -f \"$tmp\"",
            "/usr/bin/install -o root -g wheel -m 0440 \"$tmp\" \(sudoersFile)",
            "/bin/rm -f \"$tmp\"",
        ].joined(separator: " && ")

        let escaped = cmd
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges " +
            "with prompt \"Disleep needs one-time administrator access to control sleep without future password prompts.\""
        return run("/usr/bin/osascript", ["-e", source]).status == 0
    }

    // MARK: - Sleep control

    @discardableResult
    static func setSleepDisabled(_ disabled: Bool) -> Bool {
        run("/usr/bin/sudo", ["-n", pmsetPath, "-a", "disablesleep", disabled ? "1" : "0"]).status == 0
    }

    static func systemSleepDisabled() -> Bool {
        let out = run(pmsetPath, ["-g"]).output
        for line in out.split(separator: "\n") {
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
            if lower.hasPrefix("sleepdisabled") {
                return lower.hasSuffix("1")
            }
        }
        return false
    }

    /// Detached user-level watchdog: if the app dies for any reason while
    /// no-sleep is active, normal sleep is restored within ~5 seconds.
    static func spawnWatchdog() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 5; done; " +
            "/usr/bin/sudo -n \(pmsetPath) -a disablesleep 0"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", script]
        try? p.run()
    }

    // MARK: - Process helper

    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let stdout = Pipe()
        p.standardOutput = stdout
        p.standardError = Pipe()
        do { try p.run() } catch { return (-1, "") }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}
