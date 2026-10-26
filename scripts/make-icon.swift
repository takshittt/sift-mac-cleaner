// Renders Sift's app icon (lavender squircle with the sparkles mark) and
// writes Support/AppIcon.icns. Rerun after changing the design:
//   swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("Sift-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)

    // macOS icon grid: the shape fills ~80% of the canvas, leaving room for the shadow.
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let shape = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)

    let shadow = NSShadow()
    shadow.shadowColor = color(0x6A44B8).withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.shadowBlurRadius = s * 0.03
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    color(0x8A63D2).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Same hero gradient as the app (Theme.hero), top-left to bottom-right.
    NSGradient(colors: [color(0x6A44B8), color(0x8A63D2), color(0xB79CF0)])!
        .draw(in: shape, angle: -45)

    // Chartreuse glow, echoing the "can be freed" arc.
    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    let glow = NSGradient(colors: [color(0xDFFF66).withAlphaComponent(0.45), color(0xDFFF66).withAlphaComponent(0)])!
    glow.draw(fromCenter: NSPoint(x: rect.maxX - rect.width * 0.15, y: rect.maxY - rect.width * 0.12), radius: 0,
              toCenter: NSPoint(x: rect.maxX - rect.width * 0.15, y: rect.maxY - rect.width * 0.12),
              radius: rect.width * 0.6, options: [])
    NSGraphicsContext.restoreGraphicsState()

    let config = NSImage.SymbolConfiguration(pointSize: s * 0.42, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let size = symbol.size
        symbol.draw(in: NSRect(x: (s - size.width) / 2, y: (s - size.height) / 2, width: size.width, height: size.height))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    try render(points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let output = root.appendingPathComponent("Support/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(output.path)")
