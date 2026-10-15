// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import ImageIO
let args = CommandLine.arguments
guard args.count == 3, args[1].hasPrefix("/"), args[2].hasPrefix("/"), args[1].hasSuffix(".iconset"), args[2].hasSuffix(".xcassets") else { fatalError("Expected iconset and xcassets") }
let input = URL(fileURLWithPath: args[1], isDirectory: true)
let catalog = URL(fileURLWithPath: args[2], isDirectory: true)
let target = catalog.appendingPathComponent("ShareIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
var entries = [[String: String]]()
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(points)x\(points)" + (scale == 2 ? "@2x" : "") + ".png"
        let source = input.appendingPathComponent(filename)
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil), image.width == points * scale, image.height == points * scale else { fatalError("Missing or wrong-size PNG") }
        try FileManager.default.copyItem(at: source, to: target.appendingPathComponent(filename))
        entries.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": filename])
    }
}
let info: [String: Any] = ["version": 1, "author": "xcode"]
try JSONSerialization.data(withJSONObject: ["info": info], options: [.prettyPrinted, .sortedKeys]).write(to: catalog.appendingPathComponent("Contents.json"))
try JSONSerialization.data(withJSONObject: ["images": entries, "info": info], options: [.prettyPrinted, .sortedKeys]).write(to: target.appendingPathComponent("Contents.json"))
print("PASS all 10 macOS app-icon slots reference correctly sized PNGs")
