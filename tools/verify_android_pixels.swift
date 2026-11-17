import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let source = root.appendingPathComponent(".reference-source/assets/game/res/drawable-nodpi")
func pixels(_ url: URL) throws -> (Int, Int, String) {
  guard let data = CGImageSourceCreateWithURL(url as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(data, 0, nil)
  else {
    throw NSError(domain: "ImageDecode", code: 1, userInfo: [NSFilePathErrorKey: url.path])
  }
  let count = image.width * image.height * 4
  var bytes = [UInt8](repeating: 0, count: count)
  let success = bytes.withUnsafeMutableBytes { buffer -> Bool in
    guard
      let context = CGContext(
        data: buffer.baseAddress, width: image.width, height: image.height,
        bitsPerComponent: 8, bytesPerRow: image.width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return false }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return true
  }
  guard success else { throw NSError(domain: "ImageDecode", code: 2) }
  return (
    image.width, image.height,
    SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
  )
}
var report: [[String: Any]] = []
for file in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
  .filter({ ["webp", "png"].contains($0.pathExtension) }).sorted(by: { $0.path < $1.path })
{
  let name = file.deletingPathExtension().lastPathComponent
  let target = root.appendingPathComponent(
    "Crosswalker/Assets.xcassets/\(name).imageset/\(name).png")
  let original = try pixels(file)
  let port = try pixels(target)
  guard original == port else { fatalError("Pixel mismatch: \(name)") }
  report.append(["name": name, "width": original.0, "height": original.1, "rgbaSHA256": original.2])
}
let data = try JSONSerialization.data(
  withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try data.write(to: root.appendingPathComponent("Documentation/android-pixel-verification.json"))
print(
  "Verified \(report.count) Android → iOS images: identical decoded RGBA pixels and dimensions.")
