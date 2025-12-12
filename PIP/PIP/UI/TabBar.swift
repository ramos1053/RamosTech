import SwiftUI
import UniformTypeIdentifiers

/// Tab bar showing all open documents with drag-to-reorder
struct TabBar: View {
    @ObservedObject var tabManager: TabManager
    @State private var draggingTabID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                    TabItem(
                        tab: tab,
                        isActive: tabManager.activeTabID == tab.id,
                        isDragging: draggingTabID == tab.id,
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
                    .onDrag {
                        draggingTabID = tab.id
                        return NSItemProvider(object: tab.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: TabDropDelegate(
                        tabManager: tabManager,
                        currentTab: tab,
                        currentIndex: index,
                        draggingTabID: $draggingTabID
                    ))
                }
            }
        }
        .frame(height: 28)
    }
}

/// Drop delegate for tab reordering
struct TabDropDelegate: DropDelegate {
    let tabManager: TabManager
    let currentTab: TabDocument
    let currentIndex: Int
    @Binding var draggingTabID: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggingTabID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID = draggingTabID,
              draggingID != currentTab.id,
              tabManager.tabs.firstIndex(where: { $0.id == draggingID }) != nil else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            tabManager.moveTab(tabID: draggingID, to: currentIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        return draggingTabID != nil
    }
}

/// Individual tab item
struct TabItem: View {
    @ObservedObject var tab: TabDocument
    let isActive: Bool
    let isDragging: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered: Bool = false
    @State private var isEditing: Bool = false
    @State private var editingName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            // Tab content area (icon and text) - handles tap gestures
            HStack(spacing: 4) {
                // File icon
                Image(systemName: tab.isExecutable ? "terminal.fill" : "doc.text.fill")
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? .primary : .secondary)

                // File name or TextField for editing
                if isEditing {
                    TextField("Tab name", text: $editingName, onCommit: {
                        saveTabName()
                    })
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .frame(minWidth: 60, maxWidth: 150)
                    .focused($isTextFieldFocused)
                    .onAppear {
                        isTextFieldFocused = true
                    }
                } else {
                    Text(tab.fullDisplayName)
                        .font(.system(size: 12))
                        .foregroundColor(isActive ? .primary : .secondary)
                        .lineLimit(1)
                }
            }
            .onTapGesture(count: 2) {
                // Double-click to rename
                startEditing()
            }
            .onTapGesture {
                // Single click to select
                if !isEditing {
                    onSelect()
                }
            }

            // Close button - separate from tap gesture area
            if !isEditing {
                ZStack {
                    Circle()
                        .fill(closeButtonColor)
                        .frame(width: 14, height: 14)

                    if tab.isModified {
                        // Black dot for unsaved changes
                        Circle()
                            .fill(Color.black)
                            .frame(width: 6, height: 6)
                    } else if isHovered {
                        // X icon on hover
                        Image(systemName: "xmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 16, height: 16) // Slightly larger hit area
                .contentShape(Rectangle()) // Make entire area clickable
                .onTapGesture {
                    onClose()
                }
                .help(tab.isModified ? "Close (unsaved changes)" : "Close")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(tabBackground)
        .cornerRadius(6, corners: [.topLeft, .topRight])
        .opacity(isDragging ? 0.5 : 1.0)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Rename Tab") {
                startEditing()
            }

            Divider()

            Button("Close Tab") {
                onClose() // This will call the CustomWindowDelegate.shared.handleCloseTab method
            }
        }
    }

    private func startEditing() {
        editingName = tab.fullDisplayName
        isEditing = true
    }

    private func saveTabName() {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            tab.customName = trimmed
        }
        isEditing = false
    }

    private var tabBackground: Color {
        if isActive {
            return Color(NSColor.controlBackgroundColor).opacity(1.0)
        } else if isHovered {
            return Color(NSColor.controlBackgroundColor).opacity(0.5)
        } else {
            return Color(NSColor.controlBackgroundColor).opacity(0.3)
        }
    }

    private var closeButtonColor: Color {
        if tab.isModified {
            // Red button with black dot
            return Color(NSColor.systemRed)
        } else if isHovered {
            // Gray button with X on hover
            return Color(NSColor.systemGray)
        } else {
            // Invisible when not hovered and not modified
            return Color.clear
        }
    }
}

/// Helper to round specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = NSBezierPath(
            roundedRect: NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height),
            byRoundingCorners: corners,
            cornerRadius: radius
        )
        return Path(path.cgPath)
    }
}

extension NSBezierPath {
    convenience init(roundedRect rect: NSRect, byRoundingCorners corners: UIRectCorner, cornerRadius: CGFloat) {
        self.init()

        let topLeft = rect.origin
        let topRight = NSPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = NSPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = NSPoint(x: rect.minX, y: rect.maxY)

        if corners.contains(.topLeft) {
            move(to: NSPoint(x: topLeft.x + cornerRadius, y: topLeft.y))
        } else {
            move(to: topLeft)
        }

        if corners.contains(.topRight) {
            line(to: NSPoint(x: topRight.x - cornerRadius, y: topRight.y))
            curve(to: NSPoint(x: topRight.x, y: topRight.y + cornerRadius),
                  controlPoint1: topRight,
                  controlPoint2: topRight)
        } else {
            line(to: topRight)
        }

        if corners.contains(.bottomRight) {
            line(to: NSPoint(x: bottomRight.x, y: bottomRight.y - cornerRadius))
            curve(to: NSPoint(x: bottomRight.x - cornerRadius, y: bottomRight.y),
                  controlPoint1: bottomRight,
                  controlPoint2: bottomRight)
        } else {
            line(to: bottomRight)
        }

        if corners.contains(.bottomLeft) {
            line(to: NSPoint(x: bottomLeft.x + cornerRadius, y: bottomLeft.y))
            curve(to: NSPoint(x: bottomLeft.x, y: bottomLeft.y - cornerRadius),
                  controlPoint1: bottomLeft,
                  controlPoint2: bottomLeft)
        } else {
            line(to: bottomLeft)
        }

        if corners.contains(.topLeft) {
            line(to: NSPoint(x: topLeft.x, y: topLeft.y + cornerRadius))
            curve(to: NSPoint(x: topLeft.x + cornerRadius, y: topLeft.y),
                  controlPoint1: topLeft,
                  controlPoint2: topLeft)
        } else {
            close()
        }
    }

    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)

        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}

struct UIRectCorner: OptionSet {
    let rawValue: Int

    static let topLeft = UIRectCorner(rawValue: 1 << 0)
    static let topRight = UIRectCorner(rawValue: 1 << 1)
    static let bottomLeft = UIRectCorner(rawValue: 1 << 2)
    static let bottomRight = UIRectCorner(rawValue: 1 << 3)
    static let allCorners: UIRectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

#Preview("Tab Bar - Multiple Files") {
    TabBarMultipleFilesPreview()
}

#Preview("Tab Bar - Single File") {
    TabBarSingleFilePreview()
}

struct TabBarMultipleFilesPreview: View {
    @StateObject private var manager = TabManager()

    var body: some View {
        TabBar(tabManager: manager)
            .frame(height: 32)
            .onAppear {
                manager.createNewTab()
                manager.tabs[0].textEngine.loadText("print('Hello World')")

                manager.openFile(content: "#!/bin/bash\necho 'test'", documentInfo: DocumentManager.DocumentInfo(
                    url: URL(fileURLWithPath: "/Users/test/script.sh"),
                    format: .shell,
                    encoding: .utf8,
                    isRemote: false
                ))

                manager.openFile(content: "Some text", documentInfo: DocumentManager.DocumentInfo(
                    url: URL(fileURLWithPath: "/Users/test/document.txt"),
                    format: .plainText,
                    encoding: .utf8,
                    isRemote: false
                ))

                manager.tabs[0].isModified = true
            }
    }
}

struct TabBarSingleFilePreview: View {
    @StateObject private var manager = TabManager()

    var body: some View {
        TabBar(tabManager: manager)
            .frame(height: 32)
            .onAppear {
                manager.createNewTab()
            }
    }
}
