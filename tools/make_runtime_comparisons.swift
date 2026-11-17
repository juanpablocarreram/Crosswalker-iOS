import AppKit
import Foundation

// Preserve the original captures; comparisons only scale and arrange them for review.
let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let folder = root.appendingPathComponent("Documentation/verification/runtime")
let output = folder.appendingPathComponent("comparisons")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let scenes = ["home", "tutorial-00", "tutorial-map", "tutorial-crossing", "tutorial-launch", "tutorial-tool-help", "level-01-running-moved", "collision-result", "level-07-plan", "level-09-running", "level-12-plan", "level-12-won"]
for scene in scenes {
  let sources = [("android", "Android · 411 dp"), ("ios", "iPhone · 402 pt"), ("compact", "iPhone SE · 375 pt")]
    .compactMap { name, label -> (NSImage, String)? in
      let liveHome = folder.appendingPathComponent("\(name)/home-live.png")
      let source = scene == "home" && FileManager.default.fileExists(atPath: liveHome.path)
        ? liveHome : folder.appendingPathComponent("\(name)/\(scene).png")
      guard let image = NSImage(contentsOf: source) else { return nil }
      return (image, label)
    }
  guard sources.count >= 2 else { continue }
  let column: CGFloat = 360
  let gap: CGFloat = 16
  let width = Int(CGFloat(sources.count) * (column + gap) + gap)
  let height = 860
  let pixels = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: pixels)
  NSColor(white: 0.94, alpha: 1).setFill()
  NSBezierPath(rect: CGRect(x: 0, y: 0, width: width, height: height)).fill()
  for (index, pair) in sources.enumerated() {
    let (image, label) = pair
    let x = gap + CGFloat(index) * (column + gap)
    let h = min(806, column * image.size.height / image.size.width)
    let w = h * image.size.width / image.size.height
    (label as NSString).draw(at: CGPoint(x: x, y: CGFloat(height) - 28), withAttributes: [
      .font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: NSColor.black])
    image.draw(in: CGRect(x: x + (column - w) / 2, y: CGFloat(height) - 38 - h, width: w, height: h),
      from: .zero, operation: .sourceOver, fraction: 1)
  }
  NSGraphicsContext.restoreGraphicsState()
  try pixels.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(scene).png"))
}
