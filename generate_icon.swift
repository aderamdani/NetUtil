#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO

func createIcon(size: Int) -> CGImage? {
    let s = CGFloat(size)
    let ctx = CGContext(data: nil, width: size, height: size,
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    // Background: rounded rect, deep navy gradient
    let radius = s * 0.225
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    // Gradient background
    let colors = [CGColor(red: 0.055, green: 0.118, blue: 0.275, alpha: 1),  // #0E1E46
                  CGColor(red: 0.082, green: 0.259, blue: 0.459, alpha: 1)]  // #154276
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: colors as CFArray,
                               locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: s * 0.2, y: s),
                           end: CGPoint(x: s * 0.8, y: 0),
                           options: [])

    let cx = s / 2
    let cy = s / 2

    // --- Concentric arcs (ping / traceroute rings) ---
    let arcColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.85)
    let radii: [(CGFloat, CGFloat)] = [(0.14, 2.5), (0.24, 2.0), (0.34, 1.5)]
    for (ratio, lw) in radii {
        ctx.setStrokeColor(arcColor)
        ctx.setLineWidth(s * lw / 100)
        ctx.setLineCap(.round)
        // Draw 3/4 arc (open at bottom-left)
        ctx.addArc(center: CGPoint(x: cx, y: cy),
                   radius: s * ratio,
                   startAngle: CGFloat.pi * 0.75,
                   endAngle: CGFloat.pi * 0.25,
                   clockwise: false)
        ctx.strokePath()
    }

    // --- 4 node dots on outer ring ---
    let nodeR = s * 0.34
    let nodeAngles: [CGFloat] = [.pi * 0.0, .pi * 0.5, .pi * 1.0, .pi * 1.5]
    for angle in nodeAngles {
        let nx = cx + nodeR * cos(angle)
        let ny = cy + nodeR * sin(angle)
        let dotSize = s * 0.04
        ctx.setFillColor(CGColor(red: 0.4, green: 0.78, blue: 1.0, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: nx - dotSize, y: ny - dotSize,
                                    width: dotSize * 2, height: dotSize * 2))
        // White ring around dot
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
        ctx.setLineWidth(s * 0.012)
        ctx.strokeEllipse(in: CGRect(x: nx - dotSize, y: ny - dotSize,
                                      width: dotSize * 2, height: dotSize * 2))
    }

    // --- Center dot ---
    let centerDotR = s * 0.06
    ctx.setFillColor(CGColor(red: 0.4, green: 0.78, blue: 1.0, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: cx - centerDotR, y: cy - centerDotR,
                                width: centerDotR * 2, height: centerDotR * 2))
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(s * 0.018)
    ctx.strokeEllipse(in: CGRect(x: cx - centerDotR, y: cy - centerDotR,
                                  width: centerDotR * 2, height: centerDotR * 2))

    // --- Spoke lines from center to outer nodes ---
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.25))
    ctx.setLineWidth(s * 0.012)
    ctx.setLineDash(phase: 0, lengths: [s * 0.04, s * 0.025])
    for angle in nodeAngles {
        let nx = cx + nodeR * cos(angle)
        let ny = cy + nodeR * sin(angle)
        ctx.move(to: CGPoint(x: cx, y: cy))
        ctx.addLine(to: CGPoint(x: nx, y: ny))
        ctx.strokePath()
    }

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
