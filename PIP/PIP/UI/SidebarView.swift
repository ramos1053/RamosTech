import SwiftUI

/// Sidebar showing open files and file operations
struct SidebarView: View {
    @ObservedObject var tabManager: TabManager
    let onNewFile: () -> Void
    let onOpenFile: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack(spacing: 8) {
                Text("Files")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: onNewFile) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("New File (⌘N)")

                Button(action: onOpenFile) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Open File (⌘O)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // File list
            if !tabManager.tabs.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(tabManager.tabs) { tab in
                            SidebarFileItem(
                                tab: tab,
                                isActive: tabManager.activeTabID == tab.id,
                                onSelect: {
                                    tabManager.switchToTab(tab.id)
                                },
                                onClose: {
                                    // Use the delegate method to show save dialog if needed
                                    Task { @MainActor in
                                        _ = CustomWindowDelegate.shared.handleCloseTab(tab, tabManager: tabManager, closeWindow: false)
                                    }
                                }
                            )
                        }
                    }
                }
            } else {
                Spacer()
            }
        }
        .frame(width: 220)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

/// Individual file item in sidebar
struct SidebarFileItem: View {
    @ObservedObject var tab: TabDocument
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered: Bool = false
    @State private var isEditing: Bool = false
    @State private var editingName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            // File icon
            Image(systemName: fileIcon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 16)

            // File name or text field
            if isEditing {
                TextField("File name", text: $editingName, onCommit: {
                    saveFileName()
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isTextFieldFocused)
            } else {
                Text(tab.displayName)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Modified indicator or close button
            if isHovered && !isEditing {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            } else if tab.isModified {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            if !isEditing {
                onSelect()
            }
        }
        .onTapGesture(count: 2) {
            startEditing()
        }
        .contextMenu {
            Button("Rename") {
                startEditing()
            }

            Divider()

            Button("Close") {
                onClose() // This will call the CustomWindowDelegate.shared.handleCloseTab method
            }
        }
        .onChange(of: isTextFieldFocused) { _, focused in
            if !focused && isEditing {
                saveFileName()
            }
        }
    }

    private var fileIcon: String {
        if tab.isExecutable {
            return "terminal"
        } else if let ext = tab.documentInfo?.url.pathExtension.lowercased() {
            switch ext {
            case "txt": return "doc.text"
            case "sh", "bash", "zsh": return "terminal"
            case "py": return "doc.text"
            case "js", "ts": return "doc.text"
            case "csv": return "tablecells"
            default: return "doc"
            }
        }
        return "doc"
    }

    private var iconColor: Color {
        if isActive {
            return .accentColor
        } else {
            return .secondary
        }
    }

    private var backgroundColor: Color {
        if isActive {
            return Color.blue.opacity(0.2)
        } else if isHovered {
            return Color(NSColor.controlBackgroundColor).opacity(0.8)
        } else {
            return Color.clear
        }
    }

    private func startEditing() {
        editingName = tab.fullDisplayName
        isEditing = true
        isTextFieldFocused = true
    }

    private func saveFileName() {
        isEditing = false
        isTextFieldFocused = false

        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            tab.customName = trimmed
        }
    }
}

#Preview("Sidebar - Multiple Files") {
    let manager = TabManager()
    manager.createNewTab()
    manager.tabs[0].textEngine.loadText("print('Hello')")
    manager.tabs[0].isModified = true

    manager.openFile(content: "#!/bin/bash\necho 'test'", documentInfo: DocumentManager.DocumentInfo(
        url: URL(fileURLWithPath: "/Users/test/script.sh"),
        format: .shell,
        encoding: .utf8,
        isRemote: false
    ))

    return SidebarView(
        tabManager: manager,
        onNewFile: { print("New file") },
        onOpenFile: { print("Open file") }
    )
}

#Preview("Sidebar - Empty") {
    let manager = TabManager()

    return SidebarView(
        tabManager: manager,
        onNewFile: { print("New file") },
        onOpenFile: { print("Open file") }
    )
}
