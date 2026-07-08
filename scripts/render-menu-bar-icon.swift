#!/usr/bin/env swift
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("usage: render-menu-bar-icon <app-icon-transparent.png> <output-dir>\n", stderr)
    exit(1)
}

let sourceURL = URL(fileURLWithPath: args[1])
let outputDir = URL(fileURLWithPath: args[2], isDirectory: true)

guard let source = NSImage(contentsOf: sourceURL),
      let cgSource = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("error: could not load \(sourceURL.path)\n", stderr)
    exit(1)
}

let width = cgSource.width
let height = cgSource.height
let side = min(width, height)
let cropX = (width - side) / 2
let cropY = (height - side) / 2

guard let cropped = cgSource.cropping(to: CGRect(x: cropX, y: cropY, width: side, height: side)) else {
    fputs("error: could not crop source image\n", stderr)
    exit(1)
}

func renderTemplateIcon(pixelSize: Int, paddingRatio: CGFloat) -> CGImage? {
    guard let context = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let bytes = context.data?.bindMemory(to: UInt8.self, capacity: pixelSize * pixelSize * 4) else {
        return nil
    }

    context.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    context.interpolationQuality = .high

    let padding = CGFloat(pixelSize) * paddingRatio
    let drawSide = CGFloat(pixelSize) - padding * 2
    context.draw(cropped, in: CGRect(x: padding, y: CGFloat(pixelSize) - padding - drawSide, width: drawSide, height: drawSide))

    // Keep the source alpha as the template mask; draw black for template tinting.
    for i in 0..<(pixelSize * pixelSize) {
        let offset = i * 4
        let alpha = bytes[offset + 3]
        bytes[offset] = 0
        bytes[offset + 1] = 0
        bytes[offset + 2] = 0
        bytes[offset + 3] = alpha > 20 ? alpha : 0
    }

    return context.makeImage()
}

func writePNG(cgImage: CGImage, to url: URL) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        return false
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    return CGImageDestinationFinalize(destination)
}

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let outputs: [(String, Int)] = [
    ("MenuBarIcon.png", 18),
    ("MenuBarIcon@2x.png", 36),
]

for (name, pixelSize) in outputs {
    guard let image = renderTemplateIcon(pixelSize: pixelSize, paddingRatio: 0.06) else {
        fputs("error: failed to render \(name)\n", stderr)
        exit(1)
    }

    let url = outputDir.appendingPathComponent(name)
    guard writePNG(cgImage: image, to: url) else {
        fputs("error: failed to write \(url.path)\n", stderr)
        exit(1)
    }
}

print("Rendered menu bar icons from \(sourceURL.lastPathComponent) in \(outputDir.path)")
