//
//  StorageLocationPicker.swift
//  Snipster
//
//  Created by Alan Ramos on 12/16/25.
//

import SwiftUI

struct StorageLocationPicker: View {
    @EnvironmentObject var viewModel: SnippetViewModel

    private func closeWindow() {
        if let window = NSApplication.shared.keyWindow {
            window.close()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage Location")
                .font(.headline)

            Text("Choose where to save your snippets")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            ForEach(StorageLocation.allCases) { location in
                Button(action: {
                    viewModel.changeStorageLocation(location)
                }) {
                    HStack {
                        Image(systemName: location.icon)
                            .frame(width: 24)

                        VStack(alignment: .leading) {
                            Text(location.rawValue)
                                .font(.body)

                            if let path = location.defaultPath {
                                Text(path.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Not available")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        Spacer()

                        if viewModel.storageLocation == location {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(viewModel.storageLocation == location ?
                                  Color.accentColor.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .disabled(location.defaultPath == nil)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") {
                    closeWindow()
                }
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 450, height: 400)
    }
}

#Preview {
    StorageLocationPicker()
        .environmentObject(SnippetViewModel())
}
