// Generates Resources/AppIcon.icns source PNG (1024x1024).
// Run: swift Resources/make_icon.swift <output.png>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/disleep_icon_1024.png"
let size: CGFloat = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS-style squircle with standard margins
let inset = size * 0.098
let squircle = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let path = NSBezierPath(roundedRect: squircle, xRadius: squircle.width * 0.225, yRadius: squircle.width * 0.225)

if let ctx = NSGraphicsContext.current {
    ctx.saveGraphicsState()
    let drop = NSShadow()
    drop.shadowColor = NSColor.black.withAlphaComponent(0.3)
    drop.shadowBlurRadius = size * 0.018
    drop.shadowOffset = NSSize(width: 0, height: -size * 0.008)
    drop.set()
    NSColor.black.setFill()
    path.fill()
    ctx.restoreGraphicsState()
}

NSGradient(
    starting: NSColor(calibratedRed: 0.19, green: 0.19, blue: 0.22, alpha: 1),
    ending: NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.09, alpha: 1)
)!.draw(in: path, angle: -90)

// the tray bolt, big, with a warm glow
let orange = NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.04, alpha: 1) // systemOrange
let cfg = NSImage.SymbolConfiguration(pointSize: 600, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [orange]))
if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
    let bs = bolt.size
    let h = squircle.height * 0.56
    let w = bs.width / bs.height * h
    let target = NSRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h)
    if let ctx = NSGraphicsContext.current {
        ctx.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = orange.withAlphaComponent(0.55)
        glow.shadowBlurRadius = size * 0.06
        glow.shadowOffset = .zero
        glow.set()
        bolt.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
        bolt.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
        ctx.restoreGraphicsState()
    }
}

NSGraphicsContext.restoreGraphicsState()

let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
