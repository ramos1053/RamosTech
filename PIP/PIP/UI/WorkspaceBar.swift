import SwiftUI

/// Workspace bar showing all workspaces with add button
struct WorkspaceBar: View {
    @ObservedObject var workspaceManager: WorkspaceManager

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(workspaceManager.workspaces) { workspace in
                        WorkspaceTabItem(
                            workspace: workspace,
                            isActive: workspaceManager.activeWorkspaceID == workspace.id,
                            onSelect: {
                                workspaceManager.switchToWorkspace(workspace.id)
                            },
                            onClose: {
                                workspaceManager.closeWorkspace(workspace)
                            },
                            onRename: { newName in
                                workspaceManager.renameWorkspace(workspace, to: newName)
                            }
                        )
                    }
                }
            }

            // Add workspace button
            Button(action: {
                workspaceManager.createNewWorkspace()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 28)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Add New Workspace")
        }
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

/// Individual workspace tab item
struct WorkspaceTabItem: View {
    @ObservedObject var workspace: Workspace
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onRename: (String) -> Void

    @State private var isHovered: Bool = false
    @State private var isEditing: Bool = false
    @State private var editingName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            // Workspace name or TextField for editing
            if isEditing {
                TextField("Workspace name", text: $editingName, onCommit: {
                    saveWorkspaceName()
                })
                .font(.system(size: 13, weight: .medium))
                .textFieldStyle(.plain)
                .frame(minWidth: 80)
                .focused($isTextFieldFocused)
            } else {
                Text(workspace.name)
                    .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                    .foregroundColor(isActive ? .primary : .secondary)
                    .lineLimit(1)
            }

            // Modified indicator
            if workspace.hasUnsavedChanges {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }

            // Close button (only show when hovered and not editing)
            if isHovered && !isEditing {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .help("Close Workspace")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            if !isActive {
                onSelect()
            }
        }
        .onTapGesture(count: 2) {
            startEditing()
        }
        .contextMenu {
            Button("Rename Workspace") {
                startEditing()
            }
            Button("Close Workspace") {
                onClose()
            }
        }
        .onChange(of: isTextFieldFocused) { _, focused in
            if !focused && isEditing {
                saveWorkspaceName()
            }
        }
    }

    private var backgroundColor: Color {
        if isActive {
            return Color.blue.opacity(0.2)
        } else if isHovered {
            return Color(NSColor.controlBackgroundColor).opacity(0.5)
        } else {
            return Color.clear
        }
    }

    private func startEditing() {
        editingName = workspace.name
        isEditing = true
        isTextFieldFocused = true
    }

    private func saveWorkspaceName() {
        isEditing = false
        isTextFieldFocused = false

        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onRename(trimmed)
        }
    }
}

#Preview("Workspace Bar - Multiple Workspaces") {
    let manager = WorkspaceManager()
    manager.createNewWorkspace()
    manager.createNewWorkspace()
    manager.workspaces[0].tabManager.createNewTab()
    manager.workspaces[0].tabManager.tabs[0].isModified = true

    return WorkspaceBar(workspaceManager: manager)
        .frame(height: 28)
}

#Preview("Workspace Bar - Single Workspace") {
    let manager = WorkspaceManager()
    return WorkspaceBar(workspaceManager: manager)
        .frame(height: 28)
}
