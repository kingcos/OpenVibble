#!/usr/bin/env swift
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Apply Apple's macOS icon treatment to a square PNG:
//   - 1024-canvas with transparent padding
//   - 824-sized icon body, centered (matches system app icons)
//   - squircle-ish rounded corners (radius 185)
// Then regenerate the full set (16 / 32 / 64 / 128 / 256 / 512 / 1024).
//
// Usage: swift make_macos_icon.swift <source_png> <output_dir>

import AppKit
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write("usage: make_macos_icon.swift <source_png> <output_dir>\n".data(using: .utf8)!)
    exit(2)
}

let sourcePath = CommandLine.arguments[1]
let outputDir = URL(fileURLWithPath: CommandLine.arguments[2])
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

guard let sourceImage = NSImage(contentsOfFile: sourcePath),
      let sourceCG = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    FileHandle.standardError.write("error: cannot read \(sourcePath)\n".data(using: .utf8)!)
    exit(1)
}

// Apple's macOS icon grid: 1024 canvas, 824 body, ~185 corner radius.
let canvas: CGFloat = 1024
let body: CGFloat = 824
let radius: CGFloat = 185
let inset = (canvas - body) / 2

func render1024() -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: Int(canvas),
        height: Int(canvas),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.interpolationQuality = .high
    ctx.clear(CGRect(x: 0, y: 0, width: canvas, height: canvas))

    // Clip to rounded rect for the body area.
    let bodyRect = CGRect(x: inset, y: inset, width: body, height: body)
    let path = CGPath(roundedRect: bodyRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    // Draw the source image filling the body rect.
    ctx.draw(sourceCG, in: bodyRect)

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"])
    }
    try data.write(to: url)
}

func resize(_ image: CGImage, to size: Int) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .high
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()
}

guard let master = render1024() else {
    FileHandle.standardError.write("error: render failed\n".data(using: .utf8)!)
    exit(1)
}

let sizes = [16, 32, 64, 128, 256, 512, 1024]
for size in sizes {
    let image: CGImage
    if size == 1024 {
        image = master
    } else if let scaled = resize(master, to: size) {
        image = scaled
    } else {
        continue
    }
    let url = outputDir.appendingPathComponent("icon_\(size).png")
    try writePNG(image, to: url)
    print("wrote \(url.lastPathComponent)")
}
