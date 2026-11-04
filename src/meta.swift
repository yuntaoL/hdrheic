import CoreGraphics
import Foundation
import ImageIO

// Copy EXIF, IPTC, XMP, and GPS from a source image onto an HEIC
// without recompressing pixels. Color-profile and orientation tags are
// left untouched so a BT.2100 HDR HEIC is not retagged as SDR.

let blocked = [
    "orientation",
    "colorspace",
    "iccprofile",
    "gamma",
    "whitepoint",
    "primarychromaticities",
    "transferfunction",
    "profiledescription",
    "colormodel",
]

func fail(_ message: String) -> Never {
    fputs("hdrheic-meta: \(message)\n", stderr)
    exit(1)
}

let args = CommandLine.arguments
guard args.count == 3 else {
    fail("usage: hdrheic-meta <source> <heic>")
}

let sourceURL = URL(fileURLWithPath: args[1])
let heicURL = URL(fileURLWithPath: args[2])

guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
    fail("could not read \(sourceURL.path)")
}
guard let heic = CGImageSourceCreateWithURL(heicURL as CFURL, nil) else {
    fail("could not read \(heicURL.path)")
}
guard let sourceMeta = CGImageSourceCopyMetadataAtIndex(source, 0, nil) else {
    exit(0)
}
guard let filtered = CGImageMetadataCreateMutableCopy(sourceMeta) else {
    exit(0)
}

var tagCount = 0
var removePaths: [String] = []
CGImageMetadataEnumerateTagsUsingBlock(sourceMeta, nil, nil) { path, tag in
    tagCount += 1
    let name = (CGImageMetadataTagCopyName(tag) as String? ?? "").lowercased()
    if blocked.contains(where: { name.contains($0) }) {
        removePaths.append(path as String)
    }
    return true
}

if tagCount == 0 {
    exit(0)
}

for path in removePaths {
    CGImageMetadataRemoveTagWithPath(filtered, nil, path as CFString)
}

let tmpURL = URL(fileURLWithPath: heicURL.path + ".meta-tmp")
try? FileManager.default.removeItem(at: tmpURL)

guard let dest = CGImageDestinationCreateWithURL(tmpURL as CFURL, "public.heic" as CFString, 1, nil) else {
    fail("could not create a temporary HEIC")
}

var error: Unmanaged<CFError>?
let options: [CFString: Any] = [
    kCGImageDestinationMetadata: filtered,
    kCGImageDestinationMergeMetadata: true,
]
let ok = CGImageDestinationCopyImageSource(dest, heic, options as CFDictionary, &error)
if !ok {
    try? FileManager.default.removeItem(at: tmpURL)
    let detail = error?.takeRetainedValue().localizedDescription ?? "unknown error"
    fail(detail)
}

do {
    _ = try FileManager.default.replaceItemAt(heicURL, withItemAt: tmpURL)
} catch {
    try? FileManager.default.removeItem(at: tmpURL)
    fail(error.localizedDescription)
}
