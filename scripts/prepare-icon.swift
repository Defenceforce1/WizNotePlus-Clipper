// SPDX-License-Identifier: GPL-3.0-or-later
// Mechanical resampling only. Keeps user-supplied art, adds transparent margin,
// and emits all standard ICNS sizes. No generated/redrawn logo or background.
import AppKit
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else { fatalError("Usage: prepare-icon.swift SOURCE_ICNS NEW_ABSOLUTE_ICONSET") }
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
guard CommandLine.arguments[2].hasPrefix("/"), !FileManager.default.fileExists(atPath: output.path),
      output.pathExtension == "iconset", let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
    fatalError("Expected existing input and new absolute .iconset output")
}
let images = (0..<CGImageSourceGetCount(source)).compactMap { CGImageSourceCreateImageAtIndex(source, $0, nil) }
guard let original = images.max(by: { $0.width * $0.height < $1.width * $1.height }), original.width >= 512 else {
    fatalError("A high-resolution original is required")
}
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
let sizes = [16, 32, 128, 256, 512]
var written = 0
for points in sizes {
    for scale in [1, 2] {
        let pixels = points * scale
        guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: pixels * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("No image context") }
        context.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        let extent = CGFloat(pixels) * 0.82, margin = (CGFloat(pixels) - extent) / 2
        let factor = min(extent / CGFloat(original.width), extent / CGFloat(original.height))
        let width = CGFloat(original.width) * factor, height = CGFloat(original.height) * factor
        context.interpolationQuality = .high
        context.draw(original, in: CGRect(x: margin + (extent - width) / 2, y: margin + (extent - height) / 2, width: width, height: height))
        guard let image = context.makeImage(), let bytes = context.data?.assumingMemoryBound(to: UInt8.self) else { fatalError("No rendered image") }
        // Ensure the canvas stayed transparent, rather than baking a gray tile.
        for corner in [0, pixels - 1, pixels * (pixels - 1), pixels * pixels - 1] {
            guard bytes[corner * 4 + 3] == 0 else { fatalError("Unexpected opaque canvas corner") }
        }
        let name = "icon_\(points)x\(points)" + (scale == 2 ? "@2x" : "") + ".png"
        guard let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("Cannot create PNG") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { fatalError("Cannot finalize PNG") }
        written += 1
    }
}
guard written == 10 else { fatalError("Incomplete icon set") }
print("PASS original artwork proportionally resampled; no AI redraw")
print("PASS transparent canvas corners in all 10 icon sizes")
print("PASS 82-percent artwork extent with consistent transparent margins")
print("PASS complete 16-through-1024-pixel icon set")
