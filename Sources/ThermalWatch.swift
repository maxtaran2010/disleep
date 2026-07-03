import AppKit
import SwiftUI

/// Watches the system thermal state (ProcessInfo) and pops a warning overlay
/// whenever the CPU heats past normal — once per escalation (fair → serious →
/// critical), re-armed when it cools back down.
final class ThermalWatch {
    static let shared = ThermalWatch()

    private var last = ProcessInfo.ThermalState.nominal
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func start() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.check() }
        check() // already hot at launch? say so once
    }

    private func check() {
        let state = ProcessInfo.processInfo.thermalState
        defer { last = state }
        guard state != .nominal, state.rawValue > last.rawValue else { return }
        show(state: state)
    }

    private func show(state: ProcessInfo.ThermalState) {
        hideWork?.cancel()
        panel?.orderOut(nil)
        panel = nil

        let view = ThermalWarningView(
            state: state,
            sleepDisabled: AppController.shared.model.sleepDisabled
        )
        let host = NSHostingView(rootView: view)
        host.setFrameSize(host.fittingSize)

        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: host.frame.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .transient]
        p.contentView = host

        var target = NSPoint.zero
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            target = NSPoint(x: f.midX - host.frame.width / 2,
                             y: f.maxY - host.frame.height - 16)
        }
        p.setFrameOrigin(NSPoint(x: target.x, y: target.y + 24))
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            p.animator().alphaValue = 1
            p.animator().setFrameOrigin(target)
        }
        panel = p

        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
    }

    private func dismiss() {
        guard let p = panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            p.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            p.orderOut(nil)
            if self?.panel === p { self?.panel = nil }
        })
    }
}

private struct ThermalWarningView: View {
    let state: ProcessInfo.ThermalState
    let sleepDisabled: Bool
    private let start = Date()

    private var color: Color { state == .critical ? .red : .orange }

    private var title: String {
        state == .critical ? "CPU critically hot" : "CPU running hot"
    }

    private var levelName: String {
        switch state {
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        default: return "Nominal"
        }
    }

    private var detail: String {
        sleepDisabled
            ? "Thermal state: \(levelName). Sleep is disabled — your Mac can't cool off by sleeping."
            : "Thermal state: \(levelName)."
    }

    var body: some View {
        HStack(spacing: 14) {
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSince(start)
                Image(systemName: state == .fair ? "thermometer.medium" : "thermometer.high")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(color)
                    .scaleEffect(1 + 0.08 * sin(t * 5))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: 340)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(color.opacity(0.5))
        )
        .shadow(color: .black.opacity(0.25), radius: 18, y: 6)
        .padding(28)
    }
}
