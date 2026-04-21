import Foundation
import CoreImage
import CoreGraphics

/// Renders a QR code to a string suitable for writing to a terminal.
///
/// Each QR module is drawn as a 2-character-wide ANSI-colored block so the
/// result is roughly square in typical monospace fonts. White and black are
/// forced via explicit ANSI color codes (40 / 47), so the code renders the
/// same regardless of the user's terminal theme.
public enum TerminalQR {
    public enum Error: Swift.Error, LocalizedError {
        case filterUnavailable
        case renderFailed

        public var errorDescription: String? {
            switch self {
            case .filterUnavailable:
                return "CIQRCodeGenerator is not available on this system."
            case .renderFailed:
                return "Failed to render QR code."
            }
        }
    }

    /// Build a QR code image for `message` and return a string ready to print.
    /// `correctionLevel` is one of "L", "M", "Q", "H".
    /// `quietZone` is the whitespace padding in modules around the QR grid.
    public static func render(
        _ message: String,
        correctionLevel: String = "M",
        quietZone: Int = 2
    ) throws -> String {
        guard let data = message.data(using: .utf8) else { throw Error.renderFailed }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw Error.filterUnavailable
        }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(correctionLevel, forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { throw Error.renderFailed }

        let context = CIContext(options: nil)
        let extent = outputImage.extent.integral
        guard let cgImage = context.createCGImage(outputImage, from: extent) else {
            throw Error.renderFailed
        }

        let modules = try extractModules(cgImage)
        return format(modules: modules, quietZone: quietZone)
    }

    private static func extractModules(_ cgImage: CGImage) throws -> [[Bool]] {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { throw Error.renderFailed }

        // Re-render into a known-format buffer so we don't have to guess
        // pixel layout coming from CoreImage.
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bytesPerRow = width
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let bitmapInfo = CGImageAlphaInfo.none.rawValue
        guard let ctx = pixels.withUnsafeMutableBytes({ buf -> CGContext? in
            guard let base = buf.baseAddress else { return nil }
            return CGContext(
                data: base,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }) else {
            throw Error.renderFailed
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // CoreImage places (0,0) at bottom-left; flip so first row is the top.
        var rows: [[Bool]] = []
        rows.reserveCapacity(height)
        for y in stride(from: height - 1, through: 0, by: -1) {
            var row: [Bool] = []
            row.reserveCapacity(width)
            let base = y * bytesPerRow
            for x in 0..<width {
                row.append(pixels[base + x] < 128)
            }
            rows.append(row)
        }
        return rows
    }

    /// Each terminal row renders two QR rows via a Unicode upper-half-block
    /// character (▀): foreground color = top QR pixel, background color =
    /// bottom QR pixel. With one char per module width and one half-block
    /// per module height, cells come out visually square in typical
    /// monospace fonts (which are roughly 2:1 tall:wide).
    private static func format(modules: [[Bool]], quietZone: Int) -> String {
        let size = modules.count
        let totalWidth = size + quietZone * 2
        let totalHeight = size + quietZone * 2

        // Pad with the quiet zone so we can index uniformly.
        let emptyRow = [Bool](repeating: false, count: totalWidth)
        var grid: [[Bool]] = Array(repeating: emptyRow, count: quietZone)
        for row in modules {
            var padded = [Bool](repeating: false, count: quietZone)
            padded.append(contentsOf: row)
            padded.append(contentsOf: [Bool](repeating: false, count: quietZone))
            grid.append(padded)
        }
        for _ in 0..<quietZone { grid.append(emptyRow) }

        var lines: [String] = []
        lines.reserveCapacity((totalHeight + 1) / 2)
        var y = 0
        while y < totalHeight {
            let topRow = grid[y]
            let bottomRow = (y + 1 < totalHeight) ? grid[y + 1] : emptyRow
            var line = ""
            for x in 0..<totalWidth {
                // Black cell = QR module; white cell = background.
                // 30 / 97 = black / bright-white foreground.
                // 40 / 107 = black / bright-white background.
                let fgCode = topRow[x] ? "30" : "97"
                let bgCode = bottomRow[x] ? "40" : "107"
                line += "\u{1B}[\(fgCode);\(bgCode)m▀"
            }
            line += "\u{1B}[0m"
            lines.append(line)
            y += 2
        }
        return lines.joined(separator: "\n")
    }
}
