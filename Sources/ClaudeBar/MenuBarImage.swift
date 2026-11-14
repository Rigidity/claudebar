import AppKit

/// Draws the menu bar label: two stacked mini bars (session on top, weekly below), each
/// coloured by pace with a tick at the even-pace point, followed by the weekly percentage.
///
/// `MenuBarExtra` renders `Text` and template images in monochrome, so the whole label is one
/// non-template image. It draws lazily with semantic colours, so it follows the menu bar's
/// light/dark appearance.
enum MenuBarImage {
    private static let barWidth: CGFloat = 28
    private static let barHeight: CGFloat = 3
    private static let gap: CGFloat = 4
    private static let height: CGFloat = 16

    static func make(session: LimitWindow?, weekly: LimitWindow?) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let text = weekly.map { "\(Int($0.usedPercent.rounded()))%" } ?? "–"
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let size = NSSize(width: barWidth + gap + ceil(textSize.width), height: height)

        let image = NSImage(size: size, flipped: true) { _ in
            drawBar(session, y: 3.5)
            drawBar(weekly, y: 9.5)
            (text as NSString).draw(
                at: NSPoint(x: barWidth + gap, y: (height - textSize.height) / 2),
                withAttributes: [.font: font, .foregroundColor: NSColor.labelColor]
            )
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = [session.map { "Session \(Int($0.usedPercent.rounded()))%" },
                                          weekly.map { "Weekly \(Int($0.usedPercent.rounded()))%" }]
            .compactMap { $0 }.joined(separator: ", ")
        return image
    }

    private static func drawBar(_ window: LimitWindow?, y: CGFloat) {
        let track = NSRect(x: 0, y: y, width: barWidth, height: barHeight)
        let radius = barHeight / 2
        NSColor.labelColor.withAlphaComponent(0.25).setFill()
        NSBezierPath(roundedRect: track, xRadius: radius, yRadius: radius).fill()

        guard let window else { return }
        let fill = NSRect(x: 0, y: y, width: barWidth * min(window.usedPercent, 100) / 100, height: barHeight)
        window.paceLevel().nsColor.setFill()
        NSBezierPath(roundedRect: fill, xRadius: radius, yRadius: radius).fill()

        if let expected = window.expectedPercent() {
            let x = min(max(barWidth * expected / 100, 0.5), barWidth - 0.5)
            NSColor.labelColor.withAlphaComponent(0.85).setFill()
            NSRect(x: x - 0.5, y: y - 1, width: 1, height: barHeight + 2).fill()
        }
    }
}

extension PaceLevel {
    var nsColor: NSColor {
        switch self {
        case .under: return .systemGreen
        case .over: return .systemOrange
        case .critical: return .systemRed
        }
    }
}
