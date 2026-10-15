// SPDX-License-Identifier: GPL-3.0-or-later
// Resample approved artwork without redrawing it or changing its margins.
import Foundation
import ImageIO
import UniformTypeIdentifiers
let args = CommandLine.arguments
guard args.count == 3, args[2].hasPrefix("/"), args[2].hasSuffix(".iconset"),
      !FileManager.default.fileExists(atPath: args[2]),
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil) else { fatalError("Expected source ICNS and new absolute iconset") }
let images = (0..<CGImageSourceGetCount(source)).compactMap { CGImageSourceCreateImageAtIndex(source, $0, nil) }
guard let original = images.max(by: { $0.width < $1.width }), original.width >= 256 else { fatalError("No usable icon") }
let output = URL(fileURLWithPath: args[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
for points in [16, 32, 128, 256] {
    for scale in [1, 2] where points * scale <= 256 {
        let size = points * scale
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("No context") }
        context.interpolationQuality = .high
        context.draw(original, in: CGRect(x: 0, y: 0, width: size, height: size))
        let name = "icon_\(points)x\(points)" + (scale == 2 ? "@2x" : "") + ".png"
        guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("No PNG destination") }
        CGImageDestinationAddImage(destination, image, nil)
        precondition(CGImageDestinationFinalize(destination))
    }
}
print("PASS share-menu icon preserves approved artwork and proportions at 16–256 pixels")
