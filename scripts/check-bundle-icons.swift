// SPDX-License-Identifier: GPL-3.0-or-later
// Package checks only: no launch, registration, credentials or user data.
import AppKit
import ImageIO
let args = CommandLine.arguments
guard args.count == 2 else { fatalError("Usage: check-bundle-icons.swift APP_PATH") }
let host = URL(fileURLWithPath: args[1], isDirectory: true)
let ext = host.appendingPathComponent("Contents/PlugIns/WizNotePlusShare.appex", isDirectory: true)
func icon(_ bundle: URL) -> URL? {
    let bytes = try! Data(contentsOf: bundle.appendingPathComponent("Contents/Info.plist"))
    let plist = try! PropertyListSerialization.propertyList(from: bytes, format: nil) as! [String: Any]
    guard let name = plist["CFBundleIconFile"] as? String else { return nil }
    precondition(!name.contains("/") && !name.contains(".."))
    return bundle.appendingPathComponent("Contents/Resources/" + (name.hasSuffix(".icns") ? name : name + ".icns"))
}
let hostIcon = icon(host), extensionIcon = icon(ext)
if hostIcon == nil && extensionIcon == nil {
    print("NOTE no local optional artwork: public source build uses system placeholder")
    exit(0)
}
precondition(hostIcon != nil && extensionIcon != nil, "Both host and extension must declare an icon")
let hostBytes = try Data(contentsOf: hostIcon!), extensionBytes = try Data(contentsOf: extensionIcon!)
precondition(!hostBytes.isEmpty && !extensionBytes.isEmpty)
print("PASS host and macOS share extension both declare existing icon resources")
precondition(extensionBytes.count < 150000, "Share-menu icon should not duplicate large native assets")
print("PASS share extension carries only a compact static menu icon")
for (label, url) in [("host", hostIcon!), ("share extension", extensionIcon!)] {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let nsImage = NSImage(contentsOf: url) else {
        fatalError("Icon cannot be decoded")
    }
    var largest = 0
    for i in 0..<CGImageSourceGetCount(source) {
        if let image = CGImageSourceCreateImageAtIndex(source, i, nil) { largest = max(largest, image.width) }
    }
    // actool can intentionally put only small legacy renditions in ICNS;
    // modern high-resolution layers reside in Assets.car instead.
    precondition(largest >= 256 && !nsImage.representations.isEmpty)
    print("PASS \(label) ICNS decodes as a native image")
}
func metadata(_ bundle: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: bundle.appendingPathComponent("Contents/Info.plist"))
    return try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: Any]
}
let hostName = try metadata(host)["CFBundleIconName"] as? String
let extName = try metadata(ext)["CFBundleIconName"] as? String
let hostCar = host.appendingPathComponent("Contents/Resources/Assets.car")
let extCar = ext.appendingPathComponent("Contents/Resources/Assets.car")
if hostName != nil || extName != nil || FileManager.default.fileExists(atPath: hostCar.path) || FileManager.default.fileExists(atPath: extCar.path) {
    precondition(hostName == "AppIcon" && extName == nil, "Native host and static share icon must use separate resolver paths")
    print("PASS host retains native icon; sharing extension explicitly selects a static icon")
    let a = try Data(contentsOf: hostCar)
    precondition(!a.isEmpty && !FileManager.default.fileExists(atPath: extCar.path))
    print("PASS native catalog packaged once, not duplicated in share extension")
}
