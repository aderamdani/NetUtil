#!/usr/bin/swift
import AppKit
import CoreGraphics

let W = 660
let H = 400
let Wf = CGFloat(W)
let Hf = CGFloat(H)

let cs  = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: W, height: H,
                   bitsPerComponent: 8, bytesPerRow: 0,
                   space: cs,
                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

// ── Background gradient (bottom → top) ───────────────────────────────────────
let grad = CGGradient(colorsSpace: cs,
    colors: [rgb(0.055, 0.082, 0.141),
             rgb(0.082, 0.122, 0.196)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(grad,
    start: CGPoint(x: Wf/2, y: 0), end: CGPoint(x: Wf/2, y: Hf),
    options: [])

// ── Dot grid ─────────────────────────────────────────────────────────────────
ctx.setFillColor(rgb(1, 1, 1, 0.045))
let spacing: CGFloat = 28
var gy = spacing / 2
while gy < Hf {
    var gx = spacing / 2
    while gx < Wf {
        ctx.fillEllipse(in: CGRect(x: gx - 1, y: gy - 1, width: 2, height: 2))
        gx += spacing
    }
    gy += spacing
}

// ── Icon positions (CG: y=0 at bottom) ──────────────────────────────────────
// create-dmg icon y=190 from top → CG y = 400-190 = 210
let leftX:  CGFloat = 165
let rightX: CGFloat = 495
let iconY:  CGFloat = 210

// ── Radial glows ─────────────────────────────────────────────────────────────
func radialGlow(cx: CGFloat, cy: CGFloat, radius: CGFloat) {
    let locs: [CGFloat] = [0, 1]
    let g = CGGradient(colorsSpace: cs,
        colors: [rgb(0.10, 0.55, 1.0, 0.20),
                 rgb(0.10, 0.55, 1.0, 0.0)] as CFArray,
        locations: locs)!
    ctx.drawRadialGradient(g,
        startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
        endCenter:   CGPoint(x: cx, y: cy), endRadius: radius,
        options: [])
}
radialGlow(cx: leftX,  cy: iconY, radius: 90)
radialGlow(cx: rightX, cy: iconY, radius: 90)

// ── Icon frames ───────────────────────────────────────────────────────────────
func roundedRect(cx: CGFloat, cy: CGFloat, size: CGFloat, r: CGFloat) -> CGPath {
    let rect = CGRect(x: cx - size/2, y: cy - size/2, width: size, height: size)
    return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
}
func iconFrame(cx: CGFloat, cy: CGFloat) {
    let path = roundedRect(cx: cx, cy: cy, size: 116, r: 26)
    ctx.addPath(path)
    ctx.setFillColor(rgb(1, 1, 1, 0.055))
    ctx.fillPath()
    // Inner glow gradient
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let glow = CGGradient(colorsSpace: cs,
        colors: [rgb(0.3, 0.6, 1.0, 0.12),
                 rgb(0.1, 0.4, 0.9, 0.0)] as CFArray,
        locations: [0, 1])!
    ctx.drawRadialGradient(glow,
        startCenter: CGPoint(x: cx, y: cy + 20), startRadius: 0,
        endCenter:   CGPoint(x: cx, y: cy), endRadius: 70,
        options: [])
    ctx.restoreGState()
    // Border
    ctx.addPath(path)
    ctx.setStrokeColor(rgb(0.3, 0.6, 1.0, 0.22))
    ctx.setLineWidth(0.75)
    ctx.strokePath()
}
iconFrame(cx: leftX,  cy: iconY)
iconFrame(cx: rightX, cy: iconY)

// ── Arrow ─────────────────────────────────────────────────────────────────────
let arrowCX: CGFloat = (leftX + rightX) / 2
let arrowCY: CGFloat = iconY
let aw: CGFloat = 78; let bodyH: CGFloat = 13; let headW: CGFloat = 26

let arrowPath = CGMutablePath()
arrowPath.move(to:    CGPoint(x: arrowCX - aw/2,         y: arrowCY - bodyH/2))
arrowPath.addLine(to: CGPoint(x: arrowCX + aw/2 - headW, y: arrowCY - bodyH/2))
arrowPath.addLine(to: CGPoint(x: arrowCX + aw/2 - headW, y: arrowCY - bodyH * 1.9))
arrowPath.addLine(to: CGPoint(x: arrowCX + aw/2,         y: arrowCY))
arrowPath.addLine(to: CGPoint(x: arrowCX + aw/2 - headW, y: arrowCY + bodyH * 1.9))
arrowPath.addLine(to: CGPoint(x: arrowCX + aw/2 - headW, y: arrowCY + bodyH/2))
arrowPath.addLine(to: CGPoint(x: arrowCX - aw/2,         y: arrowCY + bodyH/2))
arrowPath.closeSubpath()

ctx.saveGState()
ctx.addPath(arrowPath)
ctx.clip()
let arrowGrad = CGGradient(colorsSpace: cs,
    colors: [rgb(0.04, 0.48, 0.95, 0.92),
             rgb(0.22, 0.66, 1.0,  0.92)] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(arrowGrad,
    start: CGPoint(x: arrowCX - aw/2, y: arrowCY),
    end:   CGPoint(x: arrowCX + aw/2, y: arrowCY),
    options: [])
ctx.restoreGState()
ctx.addPath(arrowPath)
ctx.setStrokeColor(rgb(0.4, 0.75, 1.0, 0.35))
ctx.setLineWidth(0.5)
ctx.strokePath()

// ── Text helpers ──────────────────────────────────────────────────────────────
func drawText(_ string: String, font: NSFont, color: NSColor, cx: CGFloat, y: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let ns = string as NSString
    let sz = ns.size(withAttributes: attrs)
    // Use NSGraphicsContext wrapping the CGContext
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.current = nsCtx
    ns.draw(at: NSPoint(x: cx - sz.width/2, y: y), withAttributes: attrs)
    NSGraphicsContext.current = nil
}

// ── Title ─────────────────────────────────────────────────────────────────────
drawText("NetUtil",
    font: NSFont.systemFont(ofSize: 26, weight: .bold),
    color: .white,
    cx: Wf/2, y: Hf - 57)

// Subtitle
drawText("NETWORK DIAGNOSTICS TOOLKIT",
    font: NSFont.systemFont(ofSize: 9.5, weight: .medium),
    color: NSColor(red: 0.35, green: 0.68, blue: 1.0, alpha: 0.72),
    cx: Wf/2, y: Hf - 77)

// ── Icon labels ───────────────────────────────────────────────────────────────
let labelFont  = NSFont.systemFont(ofSize: 11, weight: .medium)
let labelColor = NSColor(white: 1, alpha: 0.62)
drawText("NetUtil",       font: labelFont, color: labelColor, cx: leftX,  y: iconY - 74)
drawText("Applications",  font: labelFont, color: labelColor, cx: rightX, y: iconY - 74)

// ── Bottom divider ────────────────────────────────────────────────────────────
ctx.setStrokeColor(rgb(1, 1, 1, 0.07))
ctx.setLineWidth(0.5)
ctx.move(to: CGPoint(x: 48, y: 52)); ctx.addLine(to: CGPoint(x: Wf - 48, y: 52))
ctx.strokePath()

// Instruction text
drawText("Drag NetUtil to Applications to install  ·  Requires macOS 15 Sequoia or later",
    font: NSFont.systemFont(ofSize: 10, weight: .regular),
    color: NSColor(white: 1, alpha: 0.30),
    cx: Wf/2, y: 22)

// Version badge
let badgeFont  = NSFont.systemFont(ofSize: 9, weight: .semibold)
let badgeColor = NSColor(red: 0.3, green: 0.65, blue: 1.0, alpha: 0.58)
let versionStr = "v1.0.0" as NSString
let versionAttrs: [NSAttributedString.Key: Any] = [.font: badgeFont, .foregroundColor: badgeColor]
let vsz = versionStr.size(withAttributes: versionAttrs)
let bx: CGFloat = Wf - vsz.width - 28; let by: CGFloat = Hf - vsz.height - 20
let badgePath = CGPath(roundedRect: CGRect(x: bx - 5, y: by - 4, width: vsz.width + 10, height: vsz.height + 8),
                       cornerWidth: 4, cornerHeight: 4, transform: nil)
ctx.addPath(badgePath)
ctx.setFillColor(rgb(0.2, 0.5, 1.0, 0.13))
ctx.fillPath()
ctx.addPath(badgePath)
ctx.setStrokeColor(rgb(0.3, 0.6, 1.0, 0.22))
ctx.setLineWidth(0.5)
ctx.strokePath()
let nsCtx2 = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.current = nsCtx2
versionStr.draw(at: NSPoint(x: bx, y: by), withAttributes: versionAttrs)
NSGraphicsContext.current = nil

// ── Save PNG ──────────────────────────────────────────────────────────────────
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "scripts/dmg_background.png"

let cgImage = ctx.makeImage()!
let url = URL(fileURLWithPath: outputPath)
let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, cgImage, nil)
CGImageDestinationFinalize(dest)
print("✓ Background saved → \(outputPath) (\(W)×\(H)px)")
