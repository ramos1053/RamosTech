import AppKit
import Foundation

/// Line number ruler view for NSTextView
class LineNumberRulerView: NSRulerView {

    var font: NSFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular) {
        didSet {
            needsDisplay = true
        }
    }

    var textColor: NSColor = NSColor.secondaryLabelColor {
        didSet {
            needsDisplay = true
        }
    }

    var backgroundColor: NSColor = NSColor.controlBackgroundColor {
        didSet {
            needsDisplay = true
        }
    }

    var showSeparator: Bool = false {
        didSet {
            needsDisplay = true
        }
    }

    private var textView: NSTextView? {
        return clientView as? NSTextView
    }

    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
        self.clientView = scrollView?.documentView
        setup()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        self.ruleThickness = 50

        // Observe text changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: nil
        )

        // Observe scroll
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(frameDidChange),
            name: NSView.frameDidChangeNotification,
            object: scrollView?.contentView
        )
    }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    @objc private func frameDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // Don't call super to prevent default ruler border
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        // Draw background
        backgroundColor.setFill()
        bounds.fill()

        // Get visible rect
        let visibleRect = scrollView?.documentVisibleRect ?? textView.visibleRect

        // Get the range of glyphs visible in the text view
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)

        if glyphRange.length == 0 {
            return
        }

        let text = textView.string as NSString

        // Count the line number for the first visible glyph
        var lineNumber = 1
        var charIndex = 0
        let firstVisibleCharIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)

        // Count newlines before the first visible character
        while charIndex < firstVisibleCharIndex && charIndex < text.length {
            if text.character(at: charIndex) == UInt16(("\n" as NSString).character(at: 0)) {
                lineNumber += 1
            }
            charIndex += 1
        }

        // Draw line numbers for each line in the visible range
        var index = firstVisibleCharIndex
        let endIndex = min(layoutManager.characterIndexForGlyph(at: glyphRange.location + glyphRange.length - 1) + 1, text.length)

        while index < endIndex {
            let lineRange = text.lineRange(for: NSRange(location: index, length: 0))

            // Get the glyph range for this line
            let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)

            // Get the bounding rect for the line
            var lineRect = layoutManager.boundingRect(forGlyphRange: lineGlyphRange, in: textContainer)

            // Adjust for text container insets
            lineRect.origin.x += textView.textContainerInset.width
            lineRect.origin.y += textView.textContainerInset.height

            // Convert to ruler coordinates
            let relativePoint = self.convert(lineRect.origin, from: textView)

            // Only draw line numbers for lines within the visible bounds
            if relativePoint.y >= 0 && relativePoint.y < bounds.height {
                // Draw the line number
                let lineNumberString = "\(lineNumber)" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor
                ]

                let size = lineNumberString.size(withAttributes: attributes)
                let xPosition = ruleThickness - size.width - 8
                let yPosition = relativePoint.y

                lineNumberString.draw(
                    at: NSPoint(x: xPosition, y: yPosition),
                    withAttributes: attributes
                )
            }

            // Move to the next line
            lineNumber += 1
            index = lineRange.upperBound

            if index >= text.length {
                break
            }
        }

        // Draw separator line if enabled
        if showSeparator {
            let separatorPath = NSBezierPath()
            separatorPath.move(to: NSPoint(x: ruleThickness - 0.5, y: bounds.minY))
            separatorPath.line(to: NSPoint(x: ruleThickness - 0.5, y: bounds.maxY))
            textColor.withAlphaComponent(0.5).setStroke()
            separatorPath.lineWidth = 1.0
            separatorPath.stroke()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

#if DEBUG
import SwiftUI

/// Preview wrapper for LineNumberRulerView
struct LineNumberRulerPreview: NSViewRepresentable {
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.string = """
        #!/usr/bin/env python3

        def hello_world():
            print("Hello, World!")
            return True

        if __name__ == "__main__":
            hello_world()
        """
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        let ruler = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
        ruler.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        ruler.textColor = NSColor.secondaryLabelColor
        ruler.backgroundColor = NSColor.controlBackgroundColor
        scrollView.verticalRulerView = ruler

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}
}

#Preview("Line Number Ruler") {
    LineNumberRulerPreview()
        .frame(width: 400, height: 300)
}
#endif
