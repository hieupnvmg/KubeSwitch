import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fm = FileManager.default
let iconset = output.appendingPathComponent("KubeSwitch.iconset")
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

func drawMark(in context: CGContext, color: CGColor) {
    context.setStrokeColor(color)
    context.setLineWidth(7)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    let hexagon = [CGPoint(x: 50, y: 88), CGPoint(x: 83, y: 69),
                   CGPoint(x: 83, y: 31), CGPoint(x: 50, y: 12),
                   CGPoint(x: 17, y: 31), CGPoint(x: 17, y: 69)]
    context.addLines(between: hexagon)
    context.closePath()
    context.strokePath()

    for points in [
        [CGPoint(x: 33, y: 60), CGPoint(x: 67, y: 60), CGPoint(x: 59, y: 68)],
        [CGPoint(x: 67, y: 40), CGPoint(x: 33, y: 40), CGPoint(x: 41, y: 32)]
    ] {
        context.addLines(between: points)
        context.strokePath()
    }
}

func render(size: Int, tile: Bool, to url: URL) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: size * 4, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(size) / 100, y: CGFloat(size) / 100)
    if tile {
        let shape = CGPath(roundedRect: CGRect(x: 7, y: 7, width: 86, height: 86),
                           cornerWidth: 20, cornerHeight: 20, transform: nil)
        context.saveGState()
        context.addPath(shape)
        context.clip()
        let colors = [CGColor(red: 0.11, green: 0.16, blue: 0.38, alpha: 1),
                      CGColor(red: 0.22, green: 0.35, blue: 0.89, alpha: 1),
                      CGColor(red: 0.20, green: 0.69, blue: 0.87, alpha: 1)]
        let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray,
                                  locations: [0, 0.65, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 10, y: 5),
                                   end: CGPoint(x: 90, y: 100), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
        context.translateBy(x: 14, y: 14)
        context.scaleBy(x: 0.72, y: 0.72)
    }
    drawMark(in: context, color: CGColor(gray: tile ? 1 : 0, alpha: 1))
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

for size in [16, 32, 128, 256, 512] {
    try render(size: size, tile: true, to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size: size * 2, tile: true, to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(size: 72, tile: false, to: output.appendingPathComponent("MenuLogo.png"))
