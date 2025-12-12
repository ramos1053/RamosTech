import SwiftUI
import AppKit

/// Character Inspector popover showing Unicode information (CotEditor-like)
struct CharacterInspectorView: View {
    let selectedText: String
    let font: NSFont?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Character Inspector")
                .font(.headline)

            if selectedText.isEmpty {
                Text("No selection")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        // Font information
                        if let font = font {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Font")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text("\(font.displayName ?? font.fontName)")
                                    .font(.system(size: 12, design: .monospaced))
                                Text("\(String(format: "%.1f", font.pointSize)) pt")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)

                            Divider()
                        }

                        ForEach(Array(selectedText.enumerated()), id: \.offset) { index, character in
                            CharacterInfoRow(character: character, index: index)
                            if index < selectedText.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            HStack {
                Text("\(selectedText.count) character\(selectedText.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .frame(width: 320)
    }
}

struct CharacterInfoRow: View {
    let character: Character
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Large character display
                Text(String(character))
                    .font(.system(size: 32))
                    .frame(width: 50, height: 50)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    // Unicode name
                    Text(unicodeName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)

                    // Code points
                    Text(codePoints)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)

                    // UTF-8 bytes
                    Text("UTF-8: \(utf8Bytes)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            // Additional info for special characters
            if let additionalInfo = additionalInfo {
                Text(additionalInfo)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    private var unicodeName: String {
        let str = String(character)
        return str.applyingTransform(.toUnicodeName, reverse: false)?
            .replacingOccurrences(of: "\\N{", with: "")
            .replacingOccurrences(of: "}", with: "")
            ?? "Unknown"
    }

    private var codePoints: String {
        let scalars = character.unicodeScalars
        return scalars.map { "U+\(String($0.value, radix: 16, uppercase: true).padding(toLength: 4, withPad: "0", startingAt: 0))" }.joined(separator: " ")
    }

    private var utf8Bytes: String {
        let str = String(character)
        return str.utf8.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    private var additionalInfo: String? {
        let scalar = character.unicodeScalars.first!

        switch scalar.value {
        case 0x00...0x1F:
            return "Control Character"
        case 0x20:
            return "Space"
        case 0x09:
            return "Tab"
        case 0x0A:
            return "Line Feed (LF)"
        case 0x0D:
            return "Carriage Return (CR)"
        case 0x200B:
            return "Zero Width Space"
        case 0x200C:
            return "Zero Width Non-Joiner"
        case 0x200D:
            return "Zero Width Joiner"
        case 0xFEFF:
            return "Byte Order Mark (BOM)"
        case 0x00A0:
            return "Non-Breaking Space"
        case 0x2028:
            return "Line Separator"
        case 0x2029:
            return "Paragraph Separator"
        default:
            return nil
        }
    }
}

#Preview {
    CharacterInspectorView(
        selectedText: "Hello, 世界! 🌍",
        font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    )
}
