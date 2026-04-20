import AppKit

/// Custom layout manager that draws invisible characters in a specified color
class ColoredInvisiblesLayoutManager: NSLayoutManager {

    var invisibleCharactersColor: NSColor = .systemGray

    // Individual invisible character type controls
    var showLineEndingsInvisible: Bool = true
    var showTabInvisible: Bool = true
    var showSpaceInvisible: Bool = true
    var showWhitespaceInvisible: Bool = true
    var showControlCharactersInvisible: Bool = true

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)

        guard showsInvisibleCharacters,
              let textStorage = textStorage,
              let _ = textContainer(forGlyphAt: glyphsToShow.location, effectiveRange: nil) else {
            return
        }

        let string = textStorage.string as NSString
        let characterRange = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)

        invisibleCharactersColor.set()

        // Draw invisible characters
        for index in characterRange.location..<NSMaxRange(characterRange) {
            guard index < string.length else { break }

            let char = string.character(at: index)
            let glyphIndex = glyphIndexForCharacter(at: index)

            // Skip if no glyph for this character
            guard glyphIndex < numberOfGlyphs else { continue }

            var symbol: String?
            var offset: CGFloat = 0

            // Determine which symbol to draw
            switch char {
            case 0x0020: // Space
                guard showSpaceInvisible else { continue }
                symbol = "·"
                offset = 2

            case 0x0009: // Tab
                guard showTabInvisible else { continue }
                symbol = "→"
                offset = 2

            case 0x000A: // Line Feed (LF)
                guard showLineEndingsInvisible else { continue }
                symbol = "¬"
                offset = 0

            case 0x000D: // Carriage Return (CR)
                guard showLineEndingsInvisible else { continue }
                symbol = "↩"
                offset = 0

            default:
                continue
            }

            guard let symbol = symbol else { continue }

            // Get the location for this glyph
            let glyphLocation = location(forGlyphAt: glyphIndex)
            let lineFragmentRect = lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            let point = NSPoint(
                x: origin.x + lineFragmentRect.origin.x + glyphLocation.x + offset,
                y: origin.y + lineFragmentRect.origin.y
            )

            // Draw the symbol
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: invisibleCharactersColor
            ]

            (symbol as NSString).draw(at: point, withAttributes: attributes)
        }
    }
}
