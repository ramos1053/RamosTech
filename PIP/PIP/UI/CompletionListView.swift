import SwiftUI

/// SwiftUI view for displaying completion suggestions
struct CompletionListView: View {
    let items: [CompletionItem]
    let selectedIndex: Int
    // NO CLOSURES - use notifications instead to avoid autorelease pool issues

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        CompletionRow(
                            item: item,
                            isSelected: index == selectedIndex
                        )
                        .id(index)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("DEBUG: CompletionListView onTapGesture for index: \(index)")
                            // Post notification instead of calling closure
                            NotificationCenter.default.post(
                                name: NSNotification.Name("CompletionItemTapped"),
                                object: nil,
                                userInfo: ["index": index]
                            )
                        }
                    }
                }
            }
            .frame(width: 300, height: 200)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
            .onChange(of: selectedIndex) { oldValue, newValue in
                // Scroll to keep selected item visible
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

/// Individual completion row
struct CompletionRow: View {
    let item: CompletionItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Icon based on kind
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .frame(width: 20)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayText)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(isSelected ? Color(NSColor.selectedTextColor) : Color(NSColor.labelColor))

                if let detail = item.detailText {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? Color(NSColor.selectedTextColor).opacity(0.8) : Color(NSColor.secondaryLabelColor))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isSelected ? Color(NSColor.selectedTextBackgroundColor) : Color.clear
        )
    }

    // MARK: - Icon Selection

    private var iconName: String {
        switch item.kind {
        case .command:
            return "terminal"
        case .flag:
            return "flag"
        case .keyword:
            return "curlybraces"  // Better represents code structure/control flow
        case .snippet:
            return "doc.text"
        case .variable:
            return "dollarsign.circle"
        case .function:
            return "function"
        }
    }

    private var iconColor: Color {
        if isSelected {
            return Color(NSColor.selectedTextColor)
        }

        switch item.kind {
        case .command:
            return Color.blue
        case .flag:
            return Color.orange
        case .keyword:
            return Color.purple
        case .snippet:
            return Color.green
        case .variable:
            return Color.cyan
        case .function:
            return Color.pink
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleItems = [
        CompletionItem(text: "echo", displayText: "echo", detailText: "Bash builtin", kind: .command, score: 80),
        CompletionItem(text: "export", displayText: "export", detailText: "Bash builtin", kind: .command, score: 80),
        CompletionItem(text: "-h", displayText: "-h", detailText: "Show help", kind: .flag, score: 90),
        CompletionItem(text: "--help", displayText: "--help", detailText: "Show help", kind: .flag, score: 85),
        CompletionItem(text: "$HOME", displayText: "$HOME", detailText: "Environment variable", kind: .variable, score: 70)
    ]

    return CompletionListView(items: sampleItems, selectedIndex: 0)
    .padding()
}
