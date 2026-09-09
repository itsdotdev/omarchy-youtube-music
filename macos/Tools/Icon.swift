import AppKit
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels).insetBy(dx: Double(pixels) * 0.06, dy: Double(pixels) * 0.06)
        let shape = NSBezierPath(roundedRect: rect, xRadius: Double(pixels) * 0.2, yRadius: Double(pixels) * 0.2)
        NSGradient(starting: NSColor(calibratedRed: 0.22, green: 0.23, blue: 0.27, alpha: 1), ending: NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.09, alpha: 1))!.draw(in: shape, angle: -90)
        let ring = NSBezierPath(ovalIn: rect.insetBy(dx: Double(pixels) * 0.16, dy: Double(pixels) * 0.16))
        NSColor(calibratedRed: 1, green: 0.28, blue: 0.31, alpha: 1).setStroke()
        ring.lineWidth = Double(pixels) * 0.035; ring.stroke()
        let play = NSBezierPath()
        play.move(to: NSPoint(x: Double(pixels) * 0.43, y: Double(pixels) * 0.34))
        play.line(to: NSPoint(x: Double(pixels) * 0.67, y: Double(pixels) * 0.5))
        play.line(to: NSPoint(x: Double(pixels) * 0.43, y: Double(pixels) * 0.66))
        play.close(); NSColor.white.setFill(); play.fill()
        NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent("icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"))
    }
}
