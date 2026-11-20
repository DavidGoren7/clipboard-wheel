#!/usr/bin/env swift
// Draws the app icon and writes every size into the asset catalog.
// Run from the repo root: swift scripts/make-icon.swift
import AppKit
import CoreGraphics

let outputDirectory = CommandLine.arguments.dropFirst().first
    ?? "ClipboardWheel/Assets.xcassets/AppIcon.appiconset"

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func circle(_ center: CGPoint, _ radius: CGFloat) -> CGRect {
    CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
}

/// A ring slice. Angles are Core Graphics angles (counterclockwise from 3 o'clock, y up).
func sector(_ center: CGPoint, inner: CGFloat, outer: CGFloat, from start: CGFloat, to end: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
    path.addArc(center: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
    path.closeSubpath()
    return path
}

/// Two short rounded bars that read as "a line of text" in a slice.
func textBars(_ ctx: CGContext, at point: CGPoint, color barColor: CGColor) {
    ctx.setFillColor(barColor)
    for (index, width) in [CGFloat(64), 40].enumerated() {
        let rect = CGRect(x: point.x - width / 2, y: point.y + 6 - CGFloat(index) * 26, width: width, height: 13)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 6.5, cornerHeight: 6.5, transform: nil))
        ctx.fillPath()
    }
}

/// Draws the icon on a 1024×1024 canvas (y up).
func drawIcon(_ ctx: CGContext) {
    // Body on the standard macOS icon grid: an 824×824 rounded square, centered.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x000000, 0.30))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0x4B4FE6))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let background = CGGradient(
        colorsSpace: sRGB,
        colors: [color(0x7DB4FF), color(0x5358EE), color(0x2E2299)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    ctx.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    let center = CGPoint(x: 512, y: 512)
    let outer: CGFloat = 304
    let inner: CGFloat = 96
    let sliceCount = 6
    let half = CGFloat.pi / CGFloat(sliceCount)
    let top = CGFloat.pi / 2

    // Glass ring.
    let ring = CGMutablePath()
    ring.addEllipse(in: circle(center, outer))
    ring.addEllipse(in: circle(center, inner))
    ctx.addPath(ring)
    ctx.setFillColor(color(0xFFFFFF, 0.20))
    ctx.fillPath(using: .evenOdd)

    // The hovered slice (top), lit up.
    ctx.saveGState()
    ctx.addPath(sector(center, inner: inner + 10, outer: outer - 10, from: top - half, to: top + half))
    ctx.clip()
    let highlight = CGGradient(colorsSpace: sRGB, colors: [color(0xFFFFFF), color(0xDCE6FF)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(highlight, start: CGPoint(x: 512, y: 512 + outer), end: CGPoint(x: 512, y: 512 + inner), options: [])
    ctx.restoreGState()

    // Slice dividers.
    ctx.setStrokeColor(color(0xFFFFFF, 0.45))
    ctx.setLineWidth(9)
    ctx.setLineCap(.round)
    for index in 0..<sliceCount {
        let angle = top + half + CGFloat(index) * 2 * half
        ctx.move(to: CGPoint(x: center.x + cos(angle) * (inner + 14), y: center.y + sin(angle) * (inner + 14)))
        ctx.addLine(to: CGPoint(x: center.x + cos(angle) * (outer - 14), y: center.y + sin(angle) * (outer - 14)))
    }
    ctx.strokePath()

    // "Text" in each slice.
    let labelRadius = (inner + outer) / 2
    for index in 0..<sliceCount {
        let angle = top + CGFloat(index) * 2 * half
        let point = CGPoint(x: center.x + cos(angle) * labelRadius, y: center.y + sin(angle) * labelRadius)
        textBars(ctx, at: point, color: index == 0 ? color(0x4B4FE6) : color(0xFFFFFF, 0.75))
    }

    // Rims and center hub.
    ctx.setStrokeColor(color(0xFFFFFF, 0.6))
    ctx.setLineWidth(7)
    ctx.strokeEllipse(in: circle(center, outer))
    ctx.setFillColor(color(0xFFFFFF, 0.30))
    ctx.fillEllipse(in: circle(center, inner - 22))
    ctx.setStrokeColor(color(0xFFFFFF, 0.55))
    ctx.setLineWidth(6)
    ctx.strokeEllipse(in: circle(center, inner - 22))
}

func renderPNG(pixels: Int) -> Data {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(ctx)
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

// macOS icon slots: (point size, scale).
let slots: [(size: Int, scale: Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [[String: String]] = []
for slot in slots {
    let fileName = "icon_\(slot.size)x\(slot.size)" + (slot.scale == 2 ? "@2x" : "") + ".png"
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(fileName)
    try renderPNG(pixels: slot.size * slot.scale).write(to: url)
    images.append(["idiom": "mac", "scale": "\(slot.scale)x", "size": "\(slot.size)x\(slot.size)", "filename": fileName])
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: URL(fileURLWithPath: outputDirectory).appendingPathComponent("Contents.json"))
print("Wrote \(slots.count) icon sizes to \(outputDirectory)")
