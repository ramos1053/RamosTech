import SwiftUI

/// Unix Command execution dialog view
struct UnixCommandView: View {
    @Binding var isPresented: Bool
    @Binding var command: String
    let onExecute: (String) -> Void

    @State private var workingDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var useCurrentFileDirectory: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Run Unix Command")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Command:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("Enter command (e.g., ls -la, grep 'pattern' file.txt)", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 450)
                    .onSubmit {
                        performExecute()
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Working Directory:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField("Directory path", text: $workingDirectory)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disabled(useCurrentFileDirectory)

                    Button(action: browseForDirectory) {
                        Image(systemName: "folder")
                            .font(.system(size: 16))
                    }
                    .help("Browse for folder")
                    .disabled(useCurrentFileDirectory)
                }
                .frame(width: 450)

                Toggle("Use current file's directory", isOn: $useCurrentFileDirectory)
                    .font(.caption)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Run") {
                    performExecute()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 550)
        .onAppear {
            // Focus the command field when dialog appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Text field will be focused automatically
            }
        }
    }

    private func performExecute() {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else {
            return
        }

        onExecute(trimmedCommand)
        isPresented = false
    }

    private func browseForDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"

        if panel.runModal() == .OK, let url = panel.url {
            workingDirectory = url.path
        }
    }
}

#Preview {
    UnixCommandView(
        isPresented: .constant(true),
        command: .constant("ls -la"),
        onExecute: { cmd in
            print("Execute command: \(cmd)")
        }
    )
}
