// SPDX-License-Identifier: GPL-3.0-or-later
// Compose supplied raster artwork only. No redrawn W, badge or scissors.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments, fm = FileManager.default
func load(_ url: URL) -> CGImage {
    guard let decoder = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(decoder, 0, nil) else { fatalError("Cannot decode \(url.path)") }
    return image
}
func canvas(_ side: Int, height: Int? = nil) -> CGContext {
    let h = height ?? side
    let ctx = CGContext(data: nil, width: side, height: h, bitsPerComponent: 8, bytesPerRow: side * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.clear(CGRect(x: 0, y: 0, width: side, height: h)); ctx.interpolationQuality = .high
    return ctx
}
func resize(_ image: CGImage, _ side: Int) -> CGImage {
    let ctx = canvas(side); ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side)); return ctx.makeImage()!
}
func save(_ image: CGImage, _ url: URL) {
    precondition(!fm.fileExists(atPath: url.path), "Do not overwrite existing output")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil); precondition(CGImageDestinationFinalize(dest))
}
guard args.count >= 3 else { fatalError("prepare BACKGROUND_PNG BADGE_PNG NEW_OUTPUT | finish OUTPUT_DIRECTORY [SHADOW_X SHADOW_Y]") }
if args[1] == "prepare" {
    precondition(args.count == 5)
    let bgURL = URL(fileURLWithPath: args[2]), badgeURL = URL(fileURLWithPath: args[3])
    let output = URL(fileURLWithPath: args[4], isDirectory: true)
    precondition(args[4].hasPrefix("/") && !fm.fileExists(atPath: output.path))
    let bg = load(bgURL), badge = load(badgeURL)
    precondition(bg.width == bg.height && bg.width >= 512 && badge.width == badge.height)
    let inspected = canvas(bg.width)
    inspected.draw(bg, in: CGRect(x: 0, y: 0, width: bg.width, height: bg.height))
    let p = inspected.data!.assumingMemoryBound(to: UInt8.self)
    var l = bg.width, r = -1, b = bg.height, t = -1
    for y in 0..<bg.height { for x in 0..<bg.width where p[(y * bg.width + x) * 4 + 3] > 0 {
        l = min(l, x); r = max(r, x); b = min(b, y); t = max(t, y)
    } }
    let crop = bg.cropping(to: CGRect(x: l, y: bg.height - t - 1, width: r - l + 1, height: t - b + 1))!
    let background = resize(crop, 1024)
    // Core Graphics uses bottom-left coordinates; layout chosen in top-left
    // terms: badge diameter 46%, center (73.5%, 73.5%). Source is 485px, so
    // the 471px placement does not upscale this user's supplied artwork.
    let diameter = 1024.0 * 0.46, centerX = 1024.0 * 0.735, centerY = 1024.0 * (1 - 0.735)
    let badgeRect = CGRect(x: centerX - diameter / 2, y: centerY - diameter / 2, width: diameter, height: diameter)
    let badgeLayer = canvas(1024); badgeLayer.draw(badge, in: badgeRect)
    let composite = canvas(1024)
    composite.draw(background, in: CGRect(x: 0, y: 0, width: 1024, height: 1024)); composite.draw(badge, in: badgeRect)
    let assets = output.appendingPathComponent("Clipper.icon/Assets", isDirectory: true)
    try fm.createDirectory(at: assets, withIntermediateDirectories: true)
    try fm.copyItem(at: bgURL, to: output.appendingPathComponent("source-background.png"))
    try fm.copyItem(at: badgeURL, to: output.appendingPathComponent("source-scissors.png"))
    let sourceBytes = try Data(contentsOf: badgeURL)
    let copiedBytes = try Data(contentsOf: output.appendingPathComponent("source-scissors.png"))
    precondition(sourceBytes == copiedBytes, "Supplied badge must remain byte-identical")
    save(background, assets.appendingPathComponent("background.png"))
    save(badgeLayer.makeImage()!, assets.appendingPathComponent("badge.png"))
    save(composite.makeImage()!, output.appendingPathComponent("composition-before-effects.png"))
    let groups: [[String: Any]] = [
        ["name": "02 Original scissors badge", "layers": [["image-name": "badge.png", "name": "Supplied circle and scissors PNG"]],
         "shadow": ["kind": "neutral", "opacity": 0.45], "translucency": ["enabled": false, "value": 0.0]],
        ["name": "01 Original main app background", "layers": [["image-name": "background.png", "name": "Original W PNG"]],
         "shadow": ["kind": "neutral", "opacity": 0.30], "translucency": ["enabled": false, "value": 0.0]]
    ]
    let manifest: [String: Any] = ["fill": ["solid": "srgb:0.24314,0.51373,1.00000,1.00000"],
        "groups": groups, "supported-platforms": ["squares": ["macOS"]]]
    try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        .write(to: output.appendingPathComponent("Clipper.icon/icon.json"))
    print("PASS supplied originals retained; no redraw; separate original-raster groups")
    print("PASS badge diameter 46%, center at 73.5%/73.5%, native source not upscaled")
    exit(0)
}
precondition(args[1] == "finish" && (args.count == 3 || args.count == 5))
let output = URL(fileURLWithPath: args[2], isDirectory: true)
let shadowX = args.count == 5 ? Double(args[3])! : 0
let shadowY = args.count == 5 ? Double(args[4])! : -14
precondition(shadowX.isFinite && shadowY.isFinite && abs(shadowX) <= 40 && abs(shadowY) <= 40)
let rendered = load(output.appendingPathComponent("render-glass.png"))
precondition(rendered.width == 1024 && rendered.height == 1024)
// Match the accepted main preview's Apple-compiled legacy sizing reference.
let rect = CGRect(x: 104, y: 104, width: 816, height: 816)
let master = canvas(1024)
master.setShadow(offset: CGSize(width: shadowX, height: shadowY), blur: 28,
    color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.38))
master.draw(rendered, in: rect)
let image = master.makeImage()!
save(image, output.appendingPathComponent("clipper-1024.png"))
save(resize(image, 320), output.appendingPathComponent("clipper-320.png"))
let set = output.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try fm.createDirectory(at: set, withIntermediateDirectories: false)
for points in [16, 32, 128, 256, 512] { for scale in [1, 2] {
    let name = "icon_\(points)x\(points)" + (scale == 2 ? "@2x" : "") + ".png"
    save(resize(image, points * scale), set.appendingPathComponent(name))
} }
// Light and dark surfaces, plus actual 64/32px samples.
let sheet = canvas(800, height: 490)
sheet.setFillColor(CGColor(srgbRed: 0.95, green: 0.96, blue: 0.97, alpha: 1))
sheet.fill(CGRect(x: 0, y: 0, width: 400, height: 490))
sheet.setFillColor(CGColor(srgbRed: 0.13, green: 0.15, blue: 0.18, alpha: 1))
sheet.fill(CGRect(x: 400, y: 0, width: 400, height: 490))
let ns = NSGraphicsContext(cgContext: sheet, flipped: false)
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
for i in 0..<2 {
    sheet.draw(image, in: CGRect(x: 40 + i * 400, y: 135, width: 320, height: 320))
    sheet.draw(resize(image, 64), in: CGRect(x: 136 + i * 400, y: 52, width: 64, height: 64))
    sheet.draw(resize(image, 32), in: CGRect(x: 224 + i * 400, y: 68, width: 32, height: 32))
    let label = NSAttributedString(string: i == 0 ? "浅色背景 · 64 / 32 px" : "深色背景 · 64 / 32 px", attributes: [
        .font: NSFont.systemFont(ofSize: 17, weight: .medium),
        .foregroundColor: i == 0 ? NSColor.darkGray : NSColor.white])
    label.draw(at: NSPoint(x: CGFloat(i * 400 + 200) - label.size().width / 2, y: 17))
}
NSGraphicsContext.restoreGraphicsState()
save(sheet.makeImage()!, output.appendingPathComponent("preview-sheet.png"))
let bytes = master.data!.assumingMemoryBound(to: UInt8.self)
for corner in [0, 1023, 1024 * 1023, 1024 * 1024 - 1] { precondition(bytes[corner * 4 + 3] == 0) }
print("PASS Apple-rendered outline, independent badge shadow, obvious external shadow")
print("PASS transparent canvas corners; 10 icon sizes; main app untouched")
