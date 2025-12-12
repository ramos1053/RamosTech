import SwiftUI
import AppKit

/// Horizontal ruler view showing measurements and margin/tab controls for rich text
struct HorizontalRulerView: View {
    @ObservedObject var preferences = AppPreferences.shared
    let documentInfo: DocumentManager.DocumentInfo?

    @State private var leftMargin: CGFloat = 0
    @State private var rightMargin: CGFloat = 0
    @State private var tabStops: [CGFloat] = []
    @State private var isDraggingLeft = false
    @State private var isDraggingRight = false

    var isRichTextDocument: Bool {
        // RTF support has been removed - this is now a plain text editor only
        return false
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background canvas with tick marks
                Canvas { context, size in
                // Draw background with toolbar color
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(NSColor.controlBackgroundColor))
                )

                // Draw tick marks and numbers
                let pixelsPerInch: CGFloat = 72.0 // Standard screen DPI
                let minorTickInterval = pixelsPerInch / 8 // 1/8 inch

                var position: CGFloat = 0
                var inch = 0

                while position < size.width {
                    let isMajorTick = (Int(position / minorTickInterval) % 8) == 0

                    if isMajorTick {
                        // Draw major tick (full height)
                        let tickPath = Path { path in
                            path.move(to: CGPoint(x: position, y: size.height - 10))
                            path.addLine(to: CGPoint(x: position, y: size.height))
                        }
                        context.stroke(tickPath, with: .color(.gray), lineWidth: 1)

                        // Draw inch number
                        if inch > 0 {
                            let text = Text("\(inch)")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)

                            context.draw(text, at: CGPoint(x: position + 2, y: 5))
                        }
                        inch += 1
                    } else {
                        // Draw minor tick (half height)
                        let tickHeight: CGFloat = ((Int(position / minorTickInterval) % 4) == 0) ? 7 : 4
                        let tickPath = Path { path in
                            path.move(to: CGPoint(x: position, y: size.height - tickHeight))
                            path.addLine(to: CGPoint(x: position, y: size.height))
                        }
                        context.stroke(tickPath, with: .color(.gray.opacity(0.5)), lineWidth: 1)
                    }

                    position += minorTickInterval
                }

                // Draw tab stops (non-interactive for now)
                if isRichTextDocument {
                    let pixelsPerInch: CGFloat = 72.0
                    let leftMarginPos = preferences.leftMargin * pixelsPerInch
                    let rightMarginPos = size.width - (preferences.rightMargin * pixelsPerInch)

                    for tabPos in preferences.tabStops {
                        let tabX = tabPos * pixelsPerInch
                        if tabX > leftMarginPos && tabX < rightMarginPos {
                            let tabPath = Path { path in
                                path.move(to: CGPoint(x: tabX, y: 0))
                                path.addLine(to: CGPoint(x: tabX, y: 6))
                            }
                            context.stroke(tabPath, with: .color(.blue), lineWidth: 2)
                        }
                    }
                }

                // Draw bottom border
                let borderPath = Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height - 0.5))
                    path.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
                }
                context.stroke(borderPath, with: .color(.gray.opacity(0.3)), lineWidth: 1)
            }

                // Interactive margin markers for rich text documents
                if isRichTextDocument {
                    let pixelsPerInch: CGFloat = 72.0
                    let leftMarginPos = preferences.leftMargin * pixelsPerInch
                    let rightMarginPos = geometry.size.width - (preferences.rightMargin * pixelsPerInch)

                    // Left margin marker (draggable)
                    MarginMarker(color: isDraggingLeft ? .blue.opacity(0.7) : .blue)
                        .frame(width: 8, height: 7)
                        .position(x: leftMarginPos, y: 3.5)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingLeft = true
                                    let newPosition = max(0, min(value.location.x, geometry.size.width))
                                    let newMargin = newPosition / pixelsPerInch
                                    preferences.leftMargin = min(3.0, max(0.0, Double(newMargin)))
                                }
                                .onEnded { _ in
                                    isDraggingLeft = false
                                }
                        )
                        .help("Drag to adjust left margin")

                    // Right margin marker (draggable)
                    MarginMarker(color: isDraggingRight ? .blue.opacity(0.7) : .blue)
                        .frame(width: 8, height: 7)
                        .position(x: rightMarginPos, y: 3.5)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingRight = true
                                    let newPosition = max(0, min(value.location.x, geometry.size.width))
                                    let newMargin = (geometry.size.width - newPosition) / pixelsPerInch
                                    preferences.rightMargin = min(3.0, max(0.0, Double(newMargin)))
                                }
                                .onEnded { _ in
                                    isDraggingRight = false
                                }
                        )
                        .help("Drag to adjust right margin")
                }
            }
        }
        .frame(height: 23)
        .onAppear {
            // Initialize margins from preferences
            leftMargin = CGFloat(preferences.leftMargin)
            rightMargin = CGFloat(preferences.rightMargin)
            tabStops = preferences.tabStops.map { CGFloat($0) }
        }
    }
}

/// Triangular marker shape for margin indicators
struct MarginMarker: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let path = Path { path in
                path.move(to: CGPoint(x: size.width / 2, y: 0))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
            }
            context.fill(path, with: .color(color))
        }
    }
}

#Preview("Horizontal Ruler - Plain Text") {
    HorizontalRulerView(documentInfo: DocumentManager.DocumentInfo(
        url: URL(fileURLWithPath: "/Users/test/script.sh"),
        format: .shell,
        encoding: .utf8,
        isRemote: false
    ))
    .frame(width: 800, height: 23)
}

#Preview("Horizontal Ruler - No Document") {
    HorizontalRulerView(documentInfo: nil)
        .frame(width: 800, height: 23)
}
