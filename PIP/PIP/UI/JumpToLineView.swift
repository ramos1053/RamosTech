import SwiftUI

/// Jump to Line dialog view
struct JumpToLineView: View {
    @Binding var isPresented: Bool
    @State private var lineNumber: String = ""
    let onJump: (Int) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Jump to Line")
                .font(.headline)

            TextField("Line Number", text: $lineNumber)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .onSubmit {
                    performJump()
                }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Jump") {
                    performJump()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(lineNumber.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 280)
        .onAppear {
            // Focus the text field when dialog appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Text field will be focused automatically
            }
        }
    }

    private func performJump() {
        guard let line = Int(lineNumber), line > 0 else {
            return
        }

        onJump(line)
        isPresented = false
    }
}

/// Extension to add jump to line functionality to EditorView
extension Notification.Name {
    static let jumpToLine = Notification.Name("jumpToLine")
}

#Preview {
    JumpToLineView(isPresented: .constant(true)) { line in
        print("Jump to line: \(line)")
    }
}
