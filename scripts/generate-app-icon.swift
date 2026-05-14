#!/usr/bin/env swift
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources")
let masterURL = resources.appendingPathComponent("AppIcon.png")
let size: CGFloat = 1024
let rect = NSRect(x: 0, y: 0, width: size, height: size)

func save(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try png.write(to: url)
}

func gradient(_ colors: [NSColor], locations: [CGFloat], start: NSPoint, end: NSPoint) {
    let nsGradient = NSGradient(colors: colors)!
    nsGradient.draw(from: start, to: end, options: [])
}

func drawArc(center: NSPoint, radius: CGFloat, start: CGFloat, end: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end)
    path.lineWidth = 70
    path.lineCapStyle = .round
    path.lineJoinStyle = .round

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
    shadow.shadowBlurRadius = 10
    shadow.shadowOffset = NSSize(width: 0, height: -3)
    shadow.set()

    color.setStroke()
    path.stroke()

    NSShadow().set()
    NSColor.white.withAlphaComponent(0.10).setStroke()
    path.lineWidth = 5
    path.stroke()
}

let image = NSImage(size: rect.size)
image.lockFocus()

gradient(
    [
        NSColor(calibratedRed: 0.050, green: 0.061, blue: 0.079, alpha: 1.0),
        NSColor(calibratedRed: 0.090, green: 0.111, blue: 0.145, alpha: 1.0),
        NSColor(calibratedRed: 0.030, green: 0.036, blue: 0.050, alpha: 1.0)
    ],
    locations: [0, 0.54, 1],
    start: NSPoint(x: 0, y: size),
    end: NSPoint(x: size, y: 0)
)

let vignette = NSBezierPath(rect: rect)
NSColor.black.withAlphaComponent(0.12).setStroke()
vignette.lineWidth = 32
vignette.stroke()

let center = NSPoint(x: size / 2, y: size / 2)
let glow = NSGradient(colors: [
    NSColor(calibratedRed: 0.05, green: 0.82, blue: 0.66, alpha: 0.18),
    NSColor(calibratedRed: 0.02, green: 0.40, blue: 0.90, alpha: 0.07),
    NSColor.clear
])!
glow.draw(in: NSBezierPath(ovalIn: NSRect(x: 154, y: 154, width: 716, height: 716)), relativeCenterPosition: NSPoint(x: -0.12, y: 0.08))

drawArc(
    center: center,
    radius: 350,
    start: 103,
    end: 178,
    color: NSColor(calibratedRed: 0.12, green: 0.84, blue: 0.68, alpha: 1)
)
drawArc(
    center: center,
    radius: 350,
    start: 182,
    end: 257,
    color: NSColor(calibratedRed: 0.08, green: 0.72, blue: 0.60, alpha: 1)
)
drawArc(
    center: center,
    radius: 350,
    start: 2,
    end: 78,
    color: NSColor(calibratedRed: 0.22, green: 0.66, blue: 1.0, alpha: 1)
)
drawArc(
    center: center,
    radius: 350,
    start: 282,
    end: 358,
    color: NSColor(calibratedRed: 0.12, green: 0.46, blue: 0.88, alpha: 1)
)

let check = NSBezierPath()
check.move(to: NSPoint(x: 378, y: 502))
check.line(to: NSPoint(x: 474, y: 408))
check.line(to: NSPoint(x: 660, y: 612))
check.lineWidth = 86
check.lineCapStyle = .round
check.lineJoinStyle = .round

let checkShadow = NSShadow()
checkShadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
checkShadow.shadowBlurRadius = 14
checkShadow.shadowOffset = NSSize(width: 0, height: -4)
checkShadow.set()
NSColor(calibratedRed: 0.09, green: 0.78, blue: 0.63, alpha: 1).setStroke()
check.stroke()

NSShadow().set()
NSColor.white.withAlphaComponent(0.12).setStroke()
check.lineWidth = 7
check.stroke()

image.unlockFocus()

try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try save(image, to: masterURL)

let downscale = Process()
downscale.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
downscale.arguments = ["-z", "1024", "1024", masterURL.path, "--out", masterURL.path]
try? downscale.run()
downscale.waitUntilExit()

print(masterURL.path)
