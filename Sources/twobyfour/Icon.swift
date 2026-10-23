import AppKit

/// The app icon: the end of a 2x4, growth rings and all, with a lumber
/// grade stamp reading "2×4" on a dark rounded square.
enum AppIcon {
    static func image(pixels: Int) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defer { NSGraphicsContext.restoreGraphicsState() }
        let cg = context.cgContext
        let s = CGFloat(pixels)

        // Apple's grid: an 824/1024 rounded square centred on the canvas.
        let tile = CGRect(x: 0, y: 0, width: s, height: s).insetBy(dx: s * 100 / 1024, dy: s * 100 / 1024)
        let shape = CGPath(roundedRect: tile, cornerWidth: s * 185 / 1024, cornerHeight: s * 185 / 1024, transform: nil)
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.03,
                     color: NSColor.black.withAlphaComponent(0.3).cgColor)
        cg.addPath(shape)
        cg.setFillColor(NSColor(srgbRed: 0.16, green: 0.18, blue: 0.21, alpha: 1).cgColor)
        cg.fillPath()
        cg.restoreGState()

        // The board's end: 3 1/2 wide by 1 1/2 tall, slightly rounded edges.
        let boardWidth = tile.width * 0.78
        let board = CGRect(x: tile.midX - boardWidth / 2, y: tile.midY - boardWidth * 1.5 / 3.5 / 2,
                           width: boardWidth, height: boardWidth * 1.5 / 3.5)
        let boardPath = CGPath(roundedRect: board, cornerWidth: s * 0.012, cornerHeight: s * 0.012, transform: nil)
        cg.saveGState()
        cg.addPath(boardPath)
        cg.clip()
        cg.setFillColor(NSColor(srgbRed: 0.93, green: 0.80, blue: 0.58, alpha: 1).cgColor)
        cg.fill(board)
        // Growth rings centred below the board, as on a real flat-sawn stud.
        let pith = CGPoint(x: board.midX - board.width * 0.12, y: board.minY - board.height * 0.9)
        cg.setStrokeColor(NSColor(srgbRed: 0.78, green: 0.58, blue: 0.36, alpha: 1).cgColor)
        cg.setLineWidth(s * 0.009)
        var radius = board.height * 0.95
        while radius < board.width * 1.2 {
            cg.strokeEllipse(in: CGRect(x: pith.x - radius, y: pith.y - radius, width: radius * 2, height: radius * 2))
            radius += board.height * 0.16
        }
        cg.restoreGState()

        // The grade stamp.
        let font = NSFont.systemFont(ofSize: board.height * 0.52, weight: .heavy)
        let text = NSAttributedString(string: "2×4", attributes: [
            .font: font,
            .foregroundColor: NSColor(srgbRed: 0.10, green: 0.32, blue: 0.62, alpha: 0.92),
        ])
        let size = text.size()
        text.draw(at: CGPoint(x: board.midX - size.width / 2, y: board.midY - size.height / 2))
        context.flushGraphics()
        return rep
    }

    /// Writes an `.iconset` folder for `iconutil`. Used by scripts/bundle.sh.
    static func writeIconset(to dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
                guard let png = image(pixels: points * scale)?.representation(using: .png, properties: [:]) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                try png.write(to: dir.appendingPathComponent(name))
            }
        }
    }
}
