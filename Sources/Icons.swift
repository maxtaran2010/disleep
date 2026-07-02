import AppKit

enum Icons {
    static let idle = symbol("moon.zzz.fill", color: nil)
    static let activeBright = symbol("bolt.fill", color: .systemOrange)
    static let activeDim = symbol("bolt.fill", color: NSColor.systemOrange.withAlphaComponent(0.35))

    private static func symbol(_ name: String, color: NSColor?) -> NSImage {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: name) else {
            return NSImage()
        }
        var config = NSImage.SymbolConfiguration(pointSize: 14.5, weight: .semibold)
        if let color {
            config = config.applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        }
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = (color == nil)
        return image
    }
}
