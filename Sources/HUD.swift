import AppKit
import QuartzCore
import SwiftUI

/// System-style translucent HUD (like the volume bezel) confirming each toggle.
enum HUD {
    private static var panel: NSPanel?
    private static var hideWork: DispatchWorkItem?

    static func show(sleepDisabled: Bool) {
        hideWork?.cancel()
        panel?.orderOut(nil)
        panel = nil

        let host = NSHostingView(rootView: HUDView(sleepDisabled: sleepDisabled))
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
            target = NSPoint(
                x: f.midX - host.frame.width / 2,
                y: f.maxY - host.frame.height + 8
            )
        }

        // slide down from under the menu bar while fading in
        p.setFrameOrigin(NSPoint(x: target.x, y: target.y + 24))
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().alphaValue = 1
            p.animator().setFrameOrigin(target)
        }
        panel = p

        let work = DispatchWorkItem { dismiss() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    private static func dismiss() {
        guard let p = panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            p.animator().alphaValue = 0
        }, completionHandler: {
            p.orderOut(nil)
            if panel === p { panel = nil }
        })
    }
}

struct HUDView: View {
    let sleepDisabled: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(sleepDisabled ? Color.orange : Color(nsColor: .systemGray))
            Text(sleepDisabled ? "Sleep Disabled" : "Sleep Enabled")
                .font(.system(size: 15, weight: .semibold))
            if sleepDisabled {
                Text("Your Mac will stay awake")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 32)
        .frame(minWidth: 190)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1))
        )
        .shadow(color: .black.opacity(0.25), radius: 18, y: 6)
        .padding(28)
    }
}
