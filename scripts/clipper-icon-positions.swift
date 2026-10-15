// SPDX-License-Identifier: GPL-3.0-or-later
// Reuse user artwork and saved material settings; generate isolated choices.
import AppKit
import ImageIO
import UniformTypeIdentifiers
let args = CommandLine.arguments, fm = FileManager.default
func load(_ url: URL) -> CGImage {
    let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}
func canvas(_ w: Int, _ h: Int? = nil) -> CGContext {
    let ctx = CGContext(data: nil, width: w, height: h ?? w, bitsPerComponent: 8, bytesPerRow: w * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.clear(CGRect(x: 0, y: 0, width: w, height: h ?? w)); ctx.interpolationQuality = .high
    return ctx
}
func save(_ image: CGImage, _ target: URL) {
    precondition(!fm.fileExists(atPath: target.path))
    let output = CGImageDestinationCreateWithURL(target as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(output, image, nil); precondition(CGImageDestinationFinalize(output))
}
precondition(args.count >= 3, "prepare|prepare-scissors SAVED_ICON ART_PNG APPLE_MASK NEW_OUTPUT | sheet OUTPUT")
if args[1] == "prepare" || args[1] == "prepare-scissors" {
    let scissorsOnly = args[1] == "prepare-scissors"
    precondition(args.count == 6 && args[5].hasPrefix("/") && !fm.fileExists(atPath: args[5]))
    let sourceIcon = URL(fileURLWithPath: args[2], isDirectory: true)
    let badgeURL = URL(fileURLWithPath: args[3]), maskURL = URL(fileURLWithPath: args[4])
    let root = URL(fileURLWithPath: args[5], isDirectory: true)
    try fm.createDirectory(at: root, withIntermediateDirectories: false)
    let snapshot = root.appendingPathComponent("user-saved-backup.icon", isDirectory: true)
    try fm.copyItem(at: sourceIcon, to: snapshot)
    try fm.copyItem(at: badgeURL, to: root.appendingPathComponent("source-scissors.png"))
    try fm.copyItem(at: maskURL, to: root.appendingPathComponent("reference-apple-mask.png"))
    let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: snapshot.appendingPathComponent("icon.json"))) as! [String: Any]
    let originalArt = load(badgeURL), mask = load(maskURL)
    var badge = originalArt
    if scissorsOnly {
        let inspected = canvas(originalArt.width, originalArt.height)
        inspected.draw(originalArt, in: CGRect(x: 0, y: 0, width: originalArt.width, height: originalArt.height))
        let p = inspected.data!.assumingMemoryBound(to: UInt8.self)
        var l = originalArt.width, r = -1, b = originalArt.height, t = -1
        for y in 0..<originalArt.height { for x in 0..<originalArt.width where p[(y * originalArt.width + x) * 4 + 3] > 0 {
            l = min(l, x); r = max(r, x); b = min(b, y); t = max(t, y)
        } }
        precondition(r >= l && t >= b)
        badge = originalArt.cropping(to: CGRect(x: l, y: originalArt.height - t - 1, width: r - l + 1, height: t - b + 1))!
        save(badge, root.appendingPathComponent("trimmed-scissors.png"))
        print("PASS transparent padding trimmed to \(badge.width)x\(badge.height); original scissors orientation/color unchanged")
    }
    precondition(mask.width == 1024 && mask.height == 1024)
    let maskCtx = canvas(1024); maskCtx.draw(mask, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let mp = maskCtx.data!.assumingMemoryBound(to: UInt8.self)
    let layouts: [(String, Double, Double, Double)] = scissorsOnly ? [
        ("A", 0.700, 0.720, 0.500), ("B", 0.740, 0.740, 0.500),
        ("C", 0.710, 0.740, 0.560), ("D", 0.770, 0.770, 0.520)] : [
        ("A", 0.775, 0.770, 0.414), ("B", 0.795, 0.790, 0.400),
        ("C", 0.815, 0.810, 0.380), ("D", 0.835, 0.830, 0.360)]
    var records: [[String: Any]] = []
    for (name, cx, cy, requestedDiameter) in layouts {
        var diameter = requestedDiameter, accepted: CGImage?, clipped = 0
        while diameter >= 0.24 {
            let side = 1024 * diameter, layer = canvas(1024)
            let ratio = side / Double(max(badge.width, badge.height))
            let width = Double(badge.width) * ratio, height = Double(badge.height) * ratio
            layer.draw(badge, in: CGRect(x: cx * 1024 - width / 2,
                y: (1 - cy) * 1024 - height / 2, width: width, height: height))
            let bp = layer.data!.assumingMemoryBound(to: UInt8.self)
            clipped = 0
            for i in 0..<(1024 * 1024) where bp[i * 4 + 3] >= 240 && mp[i * 4 + 3] < 240 { clipped += 1 }
            if clipped == 0 { accepted = layer.makeImage(); break }
            diameter -= 0.005
        }
        precondition(accepted != nil, "Could not fit supplied artwork inside Apple mask")
        let dir = root.appendingPathComponent(name, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: false)
        let icon = dir.appendingPathComponent("Clipper.icon", isDirectory: true)
        if scissorsOnly {
            try fm.createDirectory(at: icon.appendingPathComponent("Assets"), withIntermediateDirectories: true)
            // The NEW candidates contain no old circle/badge image, even as
            // an unused asset. Preserve original background settings/pixels.
            let sourceGroups = manifest["groups"] as! [[String: Any]]
            for group in sourceGroups.dropFirst() { for layer in group["layers"] as! [[String: Any]] {
                if let imageName = layer["image-name"] as? String {
                    precondition(!imageName.contains("/") && !imageName.contains(".."))
                    try fm.copyItem(at: snapshot.appendingPathComponent("Assets/\(imageName)"),
                        to: icon.appendingPathComponent("Assets/\(imageName)"))
                }
            } }
        } else { try fm.copyItem(at: snapshot, to: icon) }
        let artName = scissorsOnly ? "candidate-scissors.png" : "candidate-badge.png"
        save(accepted!, icon.appendingPathComponent("Assets/\(artName)"))
        var customized = manifest, groups = manifest["groups"] as! [[String: Any]]
        var layers = groups[0]["layers"] as! [[String: Any]]
        layers[0]["image-name"] = artName
        if scissorsOnly {
            layers[0]["name"] = "User supplied scissors PNG, no circle"
            groups[0]["name"] = "02 Supplied scissors, independently shadowed"
        }
        layers[0].removeValue(forKey: "position-specializations")
        groups[0]["layers"] = layers; customized["groups"] = groups
        // Only the isolated candidate's manifest is updated. Its pixels are
        // placed on a transparent canvas, so no platform translation diverges.
        try JSONSerialization.data(withJSONObject: customized, options: [.prettyPrinted, .sortedKeys])
            .write(to: icon.appendingPathComponent("icon.json"))
        let record: [String: Any] = ["name": name, "centerX": cx, "centerY": cy, "diameter": diameter,
            "shape": scissorsOnly ? "scissors" : "badge",
            "requestedDiameter": requestedDiameter, "clippedOpaquePixels": clipped]
        records.append(record)
        print("PASS \(name): center \(cx),\(cy), diameter \(String(format: "%.1f", diameter * 100))%, clipped opaque badge pixels: 0")
    }
    try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
        .write(to: root.appendingPathComponent("positions.json"))
    let before = try Data(contentsOf: sourceIcon.appendingPathComponent("icon.json"))
    let copied = try Data(contentsOf: snapshot.appendingPathComponent("icon.json"))
    if before != copied { print("NOTE source was saved again during generation; newest user edits left intact") }
    print("PASS snapshot material/background settings preserved; tool never writes original document")
    exit(0)
}
precondition(args[1] == "sheet" && args.count == 3)
let root = URL(fileURLWithPath: args[2], isDirectory: true)
let records = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("positions.json"))) as! [[String: Any]]
let sheet = canvas(1280, 560)
sheet.setFillColor(CGColor(srgbRed: 0.95, green: 0.96, blue: 0.97, alpha: 1))
sheet.fill(CGRect(x: 0, y: 0, width: 1280, height: 560))
let ctx = NSGraphicsContext(cgContext: sheet, flipped: false)
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ctx
for (i, record) in records.enumerated() {
    let name = record["name"] as! String, diameter = record["diameter"] as! Double
    let image = load(root.appendingPathComponent("\(name)/clipper-1024.png"))
    sheet.draw(image, in: CGRect(x: i * 320 + 8, y: 225, width: 304, height: 304))
    let shape = (record["shape"] as? String) == "scissors" ? "剪刀" : "徽章"
    let label = NSAttributedString(string: "\(name) · \(shape) \(String(format: "%.1f", diameter * 100))%", attributes: [
        .font: NSFont.systemFont(ofSize: 23, weight: .semibold), .foregroundColor: NSColor.darkGray])
    label.draw(at: NSPoint(x: CGFloat(i * 320 + 160) - label.size().width / 2, y: 199))
    sheet.draw(image, in: CGRect(x: i * 320 + 108, y: 111, width: 64, height: 64))
    sheet.draw(image, in: CGRect(x: i * 320 + 193, y: 127, width: 32, height: 32))
    sheet.setFillColor(CGColor(srgbRed: 0.13, green: 0.15, blue: 0.18, alpha: 1))
    sheet.fill(CGRect(x: i * 320, y: 0, width: 320, height: 96))
    sheet.draw(image, in: CGRect(x: i * 320 + 108, y: 15, width: 64, height: 64))
    sheet.draw(image, in: CGRect(x: i * 320 + 193, y: 31, width: 32, height: 32))
}
NSGraphicsContext.restoreGraphicsState()
save(sheet.makeImage()!, root.appendingPathComponent("comparison.png"))
print("PASS four-choice sheet includes real 64/32px samples on light/dark surfaces")
