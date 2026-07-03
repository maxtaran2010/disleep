import AppKit
import Combine
import SwiftUI

/// Playful attention-grabbing animation styles reminding you sleep is still disabled.
enum ReminderStyle: String, Codable, CaseIterable, Identifiable {
    case off
    case notch
    case edgeGlow
    case comet
    case coffee
    case eye
    case flame
    case peeker
    case ticker
    case dvd
    case ekg

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .notch: return "Dynamic Notch"
        case .edgeGlow: return "Edge Glow"
        case .comet: return "Lightning Comet"
        case .coffee: return "Coffee Break"
        case .eye: return "Insomniac Eye"
        case .flame: return "Toasty"
        case .peeker: return "Corner Peeker"
        case .ticker: return "News Ticker"
        case .dvd: return "DVD Bounce"
        case .ekg: return "Heartbeat"
        }
    }
}

/// While sleep is disabled, periodically plays the chosen animation in a
/// borderless click-through overlay so you can't forget your Mac won't sleep.
/// Never touches the menu bar — overlays float over the desktop (or the notch).
final class ReminderEngine {
    static let shared = ReminderEngine()

    private var timer: Timer?
    private var panel: NSPanel?

    func refresh() {
        timer?.invalidate()
        timer = nil
        guard Settings.shared.reminderStyle != .off else { return }
        let t = Timer.scheduledTimer(withTimeInterval: Settings.shared.reminderInterval, repeats: true) { [weak self] _ in
            guard AppController.shared.model.sleepDisabled else { return }
            self?.play()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Play once right now regardless of sleep state (Settings "Preview" button).
    func preview() { play() }

    private func play() {
        guard panel == nil else { return } // don't stack overlays
        let style = Settings.shared.reminderStyle
        guard style != .off, let screen = NSScreen.main else { return }
        let f = screen.frame
        let v = screen.visibleFrame

        let view: AnyView
        let rect: NSRect
        let duration: TimeInterval

        switch style {
        case .off:
            return
        case .notch:
            let notch = ReminderEngine.notchGeometry(on: screen)
            let baseW = notch?.width ?? 150
            let baseH = notch?.height ?? 34
            let w = baseW + 320
            let h = baseH + 46
            // real notch: hug the very top (the dead zone); no notch: sit just below the menu bar
            let top = notch != nil ? f.maxY : v.maxY
            rect = NSRect(x: f.midX - w / 2, y: top - h, width: w, height: h)
            view = AnyView(NotchIslandView(baseWidth: baseW, baseHeight: baseH, hasNotch: notch != nil))
            duration = 3.3
        case .edgeGlow:
            rect = f
            view = AnyView(EdgeGlowView())
            duration = 3.6
        case .comet:
            rect = f
            view = AnyView(CometView())
            duration = 1.8
        case .coffee:
            rect = NSRect(x: v.maxX - 210, y: v.minY + 20, width: 200, height: 220)
            view = AnyView(CoffeeView())
            duration = 3.6
        case .eye:
            rect = NSRect(x: v.maxX - 210, y: v.minY + 20, width: 200, height: 180)
            view = AnyView(InsomniacEyeView())
            duration = 3.8
        case .flame:
            rect = NSRect(x: v.minX + 20, y: v.minY + 20, width: 190, height: 170)
            view = AnyView(FlameView())
            duration = 3.2
        case .peeker:
            rect = NSRect(x: f.maxX - 140, y: f.midY - 80, width: 140, height: 160)
            view = AnyView(PeekerView())
            duration = 2.9
        case .ticker:
            rect = NSRect(x: f.minX, y: f.minY, width: f.width, height: 30)
            view = AnyView(TickerView(width: f.width))
            duration = 4.6
        case .dvd:
            rect = f
            view = AnyView(DVDBounceView())
            duration = 4.4
        case .ekg:
            rect = NSRect(x: f.minX, y: v.minY + 8, width: f.width, height: 130)
            view = AnyView(HeartbeatView())
            duration = 2.6
        }

        present(view, in: rect, for: duration)
    }

    private func present(_ view: AnyView, in rect: NSRect, for duration: TimeInterval) {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: rect.size)

        let p = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.contentView = host

        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            p.animator().alphaValue = 1
        }
        panel = p

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.dismiss(p)
        }
    }

    private func dismiss(_ p: NSPanel) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            p.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            p.orderOut(nil)
            if self?.panel === p { self?.panel = nil }
        })
    }

    /// Physical notch size, or nil on screens without one.
    private static func notchGeometry(on screen: NSScreen) -> (width: CGFloat, height: CGFloat)? {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return nil }
        let w = screen.frame.width - left.width - right.width
        guard w > 0 else { return nil }
        return (w, screen.safeAreaInsets.top)
    }
}

/// `@State` is a macro on this SDK and plain `swiftc` (CommandLineTools) has no
/// SwiftUIMacros plugin, so per-view animation state lives in tiny
/// ObservableObjects behind `@StateObject` instead.
private final class AnimState: ObservableObject {
    @Published var flagA = false
    @Published var flagB = false
    @Published var x: CGFloat = 0
    @Published var y: CGFloat = 0
    @Published var point: CGPoint = .zero
    @Published var index = 0

    init() {}
    init(x: CGFloat) { self.x = x }
}

// MARK: - 1. Dynamic Notch

/// A black island grows out of the notch (Dynamic Island style): pulsing bolt
/// on the left wing, "Still awake" on the right, then melts back in.
private struct NotchIslandView: View {
    let baseWidth: CGFloat
    let baseHeight: CGFloat
    let hasNotch: Bool
    @StateObject private var s = AnimState() // flagA = expanded, flagB = pulse

    var body: some View {
        let w = s.flagA ? baseWidth + 260 : baseWidth
        let h = s.flagA ? baseHeight + 12 : baseHeight
        ZStack(alignment: .top) {
            island(width: w, height: h)
                .shadow(color: .black.opacity(s.flagA ? 0.45 : 0), radius: 12, y: 4)

            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.orange)
                    .scaleEffect(s.flagB ? 1.25 : 0.85)
                Spacer(minLength: 0)
                Text("Still awake")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 22)
            .frame(width: w, height: h)
            .opacity(s.flagA ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { s.flagA = true }
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { s.flagB = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { s.flagA = false }
            }
        }
    }

    @ViewBuilder
    private func island(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if hasNotch {
                BottomRoundedShape(radius: s.flagA ? 18 : 9).fill(Color.black)
            } else {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous).fill(Color.black)
            }
        }
        .frame(width: width, height: height)
    }
}

/// Rectangle rounded only at the bottom corners — the notch silhouette.
private struct BottomRoundedShape: Shape {
    var radius: CGFloat
    var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - radius))
        p.addQuadCurve(to: CGPoint(x: r.maxX - radius, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + radius, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - radius), control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - 2. Edge Glow

/// The whole screen border breathes orange twice, like a slow alarm.
private struct EdgeGlowView: View {
    private let start = Date()

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSince(start)
            let breathe = 0.5 - 0.5 * cos(t * 2 * .pi / 1.7)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.orange, lineWidth: 24)
                .blur(radius: 36)
                .opacity(0.85 * breathe)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - 3. Lightning Comet

/// A bolt with a glowing trail streaks across the screen like a shooting star.
private struct CometView: View {
    @StateObject private var s = AnimState() // x = progress 0…1

    var body: some View {
        GeometryReader { geo in
            let from = CGPoint(x: -180, y: geo.size.height * 0.22)
            let to = CGPoint(x: geo.size.width + 180, y: geo.size.height * 0.62)
            let angle = atan2(to.y - from.y, to.x - from.x)
            ZStack {
                Capsule()
                    .fill(LinearGradient(colors: [.clear, .orange.opacity(0.9)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 240, height: 7)
                    .blur(radius: 3)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.yellow)
                    .shadow(color: .orange, radius: 14)
                    .offset(x: 120)
            }
            .rotationEffect(.radians(angle))
            .position(x: from.x + (to.x - from.x) * s.x,
                      y: from.y + (to.y - from.y) * s.x)
            .onAppear {
                withAnimation(.easeIn(duration: 1.5)) { s.x = 1 }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 4. Coffee Break

/// A coffee cup slides into the corner and quietly steams. Still brewing.
private struct CoffeeView: View {
    @StateObject private var s = AnimState() // flagA = shown
    private let start = Date()

    var body: some View {
        VStack(spacing: 6) {
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSince(start)
                HStack(spacing: 12) {
                    wisp(t: t, index: 0)
                    wisp(t: t, index: 1)
                    wisp(t: t, index: 2)
                }
                .frame(height: 48, alignment: .bottom)
            }
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.orange)
            Text("still brewing")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(s.flagA ? 1 : 0)
        .offset(y: s.flagA ? 0 : 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { s.flagA = true }
        }
    }

    private func wisp(t: TimeInterval, index: Int) -> some View {
        let phase = (t * 0.45 + Double(index) * 0.33).truncatingRemainder(dividingBy: 1)
        let dx = CGFloat(sin(phase * 2 * .pi + Double(index)) * 4)
        let dy = CGFloat(-phase * 32)
        return Capsule()
            .fill(Color.white.opacity(0.85))
            .frame(width: 5, height: 16)
            .offset(x: dx, y: dy)
            .opacity(sin(phase * .pi))
    }
}

// MARK: - 5. Insomniac Eye

/// An eye dozes off, snaps back open and looks around. It's watching you.
private struct InsomniacEyeView: View {
    @StateObject private var s = AnimState() // flagA = shown, x = lid 0…1, y = pupil offset

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Ellipse().fill(Color.white)
                Circle()
                    .fill(Color.black)
                    .frame(width: 26, height: 26)
                    .offset(x: s.y)
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(nsColor: .darkGray))
                        .frame(height: 64 * s.x)
                    Spacer(minLength: 0)
                }
            }
            .frame(width: 100, height: 64)
            .clipShape(Ellipse())
            .overlay(Ellipse().strokeBorder(Color.black.opacity(0.5), lineWidth: 2))
            Text("no napping")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(s.flagA ? 1 : 0)
        .scaleEffect(s.flagA ? 1 : 0.8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { s.flagA = true }
            withAnimation(.easeIn(duration: 1.1).delay(0.3)) { s.x = 1 } // dozing off…
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.6)) { s.x = 0 } // snap!
            }
            for (i, look) in [CGFloat(-20), 20, 0].enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.1 + Double(i) * 0.45) {
                    withAnimation(.easeInOut(duration: 0.25)) { s.y = look }
                }
            }
        }
    }
}

// MARK: - 6. Toasty

/// A flickering flame in the corner. Your Mac is running hot, remember?
private struct FlameView: View {
    @StateObject private var s = AnimState() // flagA = shown
    private let start = Date()

    var body: some View {
        VStack(spacing: 8) {
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSince(start)
                Image(systemName: "flame.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(colors: [.red, .orange, .yellow],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .scaleEffect(x: 1 + 0.06 * sin(t * 13), y: 1 + 0.09 * sin(t * 17 + 1), anchor: .bottom)
                    .rotationEffect(.degrees(2.5 * sin(t * 9)))
                    .shadow(color: .orange.opacity(0.7), radius: 10)
            }
            Text("running hot")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(s.flagA ? 1 : 0)
        .offset(y: s.flagA ? 0 : 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { s.flagA = true }
        }
    }
}

// MARK: - 7. Corner Peeker

/// A bolt with googly eyes peeks out of the screen edge, wiggles, hides.
private struct PeekerView: View {
    @StateObject private var s = AnimState() // flagA = out, x = tilt degrees

    var body: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 72, weight: .bold))
            .foregroundStyle(Color.orange)
            .overlay(alignment: .top) {
                HStack(spacing: 9) {
                    GooglyEye()
                    GooglyEye()
                }
                .offset(x: -4, y: 18)
            }
            .shadow(color: .orange.opacity(0.6), radius: 12)
            .rotationEffect(.degrees(s.x))
            .offset(x: s.flagA ? 26 : 130)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { s.flagA = true }
                for (i, a) in [CGFloat(-12), 12, -7, 0].enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(i) * 0.25) {
                        withAnimation(.easeInOut(duration: 0.22)) { s.x = a }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                    withAnimation(.easeIn(duration: 0.35)) { s.flagA = false }
                }
            }
    }
}

private struct GooglyEye: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.white).frame(width: 13, height: 13)
            Circle().fill(Color.black).frame(width: 6, height: 6).offset(x: 1, y: 1)
        }
        .overlay(Circle().strokeBorder(Color.black.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - 8. News Ticker

/// A breaking-news bar crawls along the bottom edge. This just in: no sleep.
private struct TickerView: View {
    @StateObject private var s: AnimState // x = text offset

    init(width: CGFloat) {
        _s = StateObject(wrappedValue: AnimState(x: width))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Color.black.opacity(0.88))
            Text(String(repeating: "BREAKING · MAC STILL AWAKE · SLEEP IS DISABLED   ", count: 8))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.orange)
                .fixedSize()
                .offset(x: s.x)
        }
        .onAppear {
            withAnimation(.linear(duration: 4.5)) { s.x = -1600 }
        }
    }
}

// MARK: - 9. DVD Bounce

/// The screensaver classic: a DISLEEP logo ricochets around, recoloring on
/// every bounce. It never hits the corner. It never will.
private struct DVDBounceView: View {
    @StateObject private var s = AnimState() // point = position, index = color
    private let colors: [Color] = [.orange, .yellow, .pink, .cyan, .green]

    var body: some View {
        GeometryReader { geo in
            let pts: [CGPoint] = [
                CGPoint(x: 0.12, y: 0.18), CGPoint(x: 0.68, y: 0.93),
                CGPoint(x: 0.95, y: 0.55), CGPoint(x: 0.50, y: 0.06),
                CGPoint(x: 0.10, y: 0.50),
            ].map { CGPoint(x: $0.x * geo.size.width, y: $0.y * geo.size.height) }

            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                Text("DISLEEP")
            }
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .foregroundStyle(colors[s.index])
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.75)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(colors[s.index], lineWidth: 2.5))
            .position(s.point)
            .onAppear {
                s.point = pts[0]
                for i in 1..<pts.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i - 1) * 0.9) {
                        withAnimation(.linear(duration: 0.9)) { s.point = pts[i] }
                        s.index = i % colors.count
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 10. Heartbeat

/// An EKG pulse draws itself across the bottom of the screen. Alive and awake.
private struct HeartbeatView: View {
    @StateObject private var s = AnimState() // x = trim progress

    var body: some View {
        HeartbeatShape()
            .trim(from: 0, to: s.x)
            .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .shadow(color: .orange.opacity(0.8), radius: 7)
            .padding(.horizontal, 40)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0)) { s.x = 1 }
            }
    }
}

private struct HeartbeatShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let y = r.midY
        func pt(_ fx: CGFloat, _ dy: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + fx * r.width, y: y + dy)
        }
        p.move(to: pt(0, 0))
        for base in [CGFloat(0.18), 0.58] {
            p.addLine(to: pt(base, 0))
            p.addLine(to: pt(base + 0.015, 8))
            p.addLine(to: pt(base + 0.035, -46))
            p.addLine(to: pt(base + 0.055, 22))
            p.addLine(to: pt(base + 0.07, 0))
        }
        p.addLine(to: pt(1, 0))
        return p
    }
}
