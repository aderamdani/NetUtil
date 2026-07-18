#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO

// Minimalist "liquid glass" app icon for NetUtil.
// A single network glyph (hub + three spokes to leaf nodes) floats over a
// soft navy gradient with a translucent glass highlight, avoiding the
// busy concentric-ring + node-dot treatment of the previous design.

func createIcon(size: Int) -> CGImage? {
    let s = CGFloat(size)
    let ctx = CGContext(data: nil, width: size, height: size,
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    let radius = s * 0.225
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let clipPath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(clipPath)
    ctx.clip()

    // --- Soft navy gradient background ---
    let bgColors = [CGColor(red: 0.063, green: 0.137, blue: 0.322, alpha: 1.0),  // #10224F
                    CGColor(red: 0.110, green: 0.290, blue: 0.510, alpha: 1.0)]  // #1C4A82
    let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: bgColors as CFArray,
                                locations: [0, 1])!
    ctx.drawLinearGradient(bgGradient,
                           start: CGPoint(x: s * 0.15, y: s * 0.9),
                           end: CGPoint(x: s * 0.85, y: s * 0.1),
                           options: [])

    let cx = s / 2
    let cy = s / 2

    // --- Translucent glass plate (simulated liquid glass) ---
    // A lighter, blurred-looking disc with low alpha gives the "glass" feel.
    let glassR = s * 0.40
    let glassColors = [CGColor(red: 1, green: 1, blue: 1, alpha: 0.22),
                       CGColor(red: 1, green: 1, blue: 1, alpha: 0.04)]
    let glassGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: glassColors as CFArray,
                                   locations: [0, 1])!
    ctx.drawRadialGradient(glassGradient,
                           startCenter: CGPoint(x: cx - glassR * 0.25, y: cy - glassR * 0.25),
                           startRadius: 0,
                           endCenter: CGPoint(x: cx, y: cy),
                           endRadius: glassR,
                           options: [])

    // Top-left specular highlight (glass sheen)
    let sheenColors = [CGColor(red: 1, green: 1, blue: 1, alpha: 0.35),
                       CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)]
    let sheenGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: sheenColors as CFArray,
                                   locations: [0, 1])!
    ctx.drawRadialGradient(sheenGradient,
                           startCenter: CGPoint(x: s * 0.32, y: s * 0.30),
                           startRadius: 0,
                           endCenter: CGPoint(x: s * 0.32, y: s * 0.30),
                           endRadius: s * 0.42,
                           options: [])

    // --- Network glyph: hub + three spokes ---
    let accent = CGColor(red: 0.43, green: 0.80, blue: 1.0, alpha: 1.0)  // #6DCCFF
    let hubR = s * 0.075
    let spokeEnd = s * 0.28
    // Three symmetric spokes (top, bottom-left, bottom-right)
    let angles: [CGFloat] = [-CGFloat.pi / 2, CGFloat.pi * 0.75, CGFloat.pi * 0.25]

    // Spokes
    ctx.setStrokeColor(accent)
    ctx.setLineWidth(s * 0.028)
    ctx.setLineCap(.round)
    for a in angles {
        let ex = cx + spokeEnd * cos(a)
        let ey = cy + spokeEnd * sin(a)
        ctx.move(to: CGPoint(x: cx, y: cy))
        ctx.addLine(to: CGPoint(x: ex, y: ey))
        ctx.strokePath()
    }

    // Leaf nodes
    let leafR = s * 0.05
    for a in angles {
        let ex = cx + spokeEnd * cos(a)
        let ey = cy + spokeEnd * sin(a)
        ctx.setFillColor(accent)
        ctx.fillEllipse(in: CGRect(x: ex - leafR, y: ey - leafR,
                                    width: leafR * 2, height: leafR * 2))
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
        ctx.setLineWidth(s * 0.010)
        ctx.strokeEllipse(in: CGRect(x: ex - leafR, y: ey - leafR,
                                      width: leafR * 2, height: leafR * 2))
    }

    // Center hub
    ctx.setFillColor(accent)
    ctx.fillEllipse(in: CGRect(x: cx - hubR, y: cy - hubR,
                                width: hubR * 2, height: hubR * 2))
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1.0))
    ctx.setLineWidth(s * 0.016)
    ctx.strokeEllipse(in: CGRect(x: cx - hubR, y: cy - hubR,
                                  width: hubR * 2, height: hubR * 2))

    // Subtle inner rim for depth
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.12))
    ctx.setLineWidth(s * 0.01)
    ctx.addPath(CGPath(roundedRect: rect.insetBy(dx: s * 0.01, dy: s * 0.01),
                       cornerWidth: radius - s * 0.01,
                       cornerHeight: radius - s * 0.01, transform: nil))
    ctx.strokePath()

    return ctx.makeImage()
}

func savePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else {
        print("❌ Cannot create destination: \(path)"); return
    }
    CGImageDestinationAddImage(dest, image, nil)
    if CGImageDestinationFinalize(dest) {
        print("✅ \(path)")
    } else {
        print("❌ Failed: \(path)")
    }
}

let iconDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "./NetUtil/Assets.xcassets/AppIcon.appiconset"

let sizes = [16, 32, 64, 128, 256, 512, 1024]
for size in sizes {
    if let img = createIcon(size: size) {
        savePNG(img, to: "\(iconDir)/icon_\(size)x\(size).png")
    }
}
