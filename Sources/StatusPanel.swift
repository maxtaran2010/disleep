import AppKit
import QuartzCore
import SwiftUI

/// Replacement for NSPopover: a panel anchored manually to the status item's
/// screen coordinates. NSPopover misplaces itself relative to status items on
/// fullscreen Spaces, so we own the math instead.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class StatusPanelController {
    private var panel: KeyPanel?
    private var monitors: [Any] = []
    private weak var button: NSStatusBarButton?

    var isShown: Bool { panel != nil }

    func toggle(from button: NSStatusBarButton, model: AppModel) {
        if isShown { close() } else { show(from: button, model: model) }
    }

    func show(from button: NSStatusBarButton, model: AppModel) {
        close(animated: false)
        self.button = button

        let host = NSHostingView(rootView: PanelChrome { MenuView(model: model) })
        host.setFrameSize(host.fittingSize)

        let p = KeyPanel(
            contentRect: NSRect(origin: .zero, size: host.frame.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.isReleasedWhenClosed = false
        p.contentView = host

        var target = NSPoint.zero
        if let win = button.window {
            let anchor = win.convertToScreen(button.convert(button.bounds, to: nil))
            var x = anchor.midX - host.frame.width / 2
            // chrome has 20pt of transparent shadow padding; land the card 6pt under the menu bar
            let y = anchor.minY - host.frame.height + 14
            if let vf = (win.screen ?? NSScreen.main)?.frame {
                x = min(max(x, vf.minX - 16), vf.maxX - host.frame.width + 16)
            }
            target = NSPoint(x: x, y: y)
        }

        // slide down out of the menu bar while fading in
        p.setFrameOrigin(NSPoint(x: target.x, y: target.y + 10))
        p.alphaValue = 0
        p.orderFrontRegardless()
        p.makeKey()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().alphaValue = 1
            p.animator().setFrameOrigin(target)
        }
        panel = p

        if let global = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown],
            handler: { [weak self] _ in
                guard let self else { return }
                // a click on the status item itself is handled by the button's
                // toggle action — closing here too would instantly reopen it
                if let button = self.button, let win = button.window {
                    let rect = win.convertToScreen(button.convert(button.bounds, to: nil))
                    if rect.insetBy(dx: -4, dy: -4).contains(NSEvent.mouseLocation) { return }
                }
                self.close()
            }
        ) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.keyDown], handler: { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.close()
                return nil
            }
            return event
        }) {
            monitors.append(local)
        }
    }

    func close(animated: Bool = true) {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        guard let p = panel else { return }
        panel = nil
        if animated {
            let up = NSPoint(x: p.frame.origin.x, y: p.frame.origin.y + 10)
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.13
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                p.animator().alphaValue = 0
                p.animator().setFrameOrigin(up)
            }, completionHandler: {
                p.orderOut(nil)
            })
        } else {
            p.orderOut(nil)
        }
    }
}

struct PanelChrome<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12))
            )
            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
            .padding(20)
    }
}
