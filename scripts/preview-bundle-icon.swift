// SPDX-License-Identifier: GPL-3.0-or-later
// Resolve the system's icon for a bundle without running that application.
import AppKit
import ImageIO
import UniformTypeIdentifiers
let args = CommandLine.arguments
guard args.count == 3, !FileManager.default.fileExists(atPath: args[2]) else {
    fatalError("Usage: preview-bundle-icon.swift BUNDLE_PATH NEW_PNG")
}
let icon = NSWorkspace.shared.icon(forFile: args[1])
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 512, pixelsHigh: 512,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: 512, height: 512).fill()
icon.draw(in: NSRect(x: 0, y: 0, width: 512, height: 512), from: .zero,
    operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: args[2]), options: .withoutOverwriting)
print("System icon resolved without launching app")
