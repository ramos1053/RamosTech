//
//  ContactPickerWindow.swift
//  Snipster
//

import SwiftUI
import AppKit

/// Presents a searchable contact list as its own standalone, resizable
/// window — not embedded/popover'd into the narrow Template Filler panel,
/// which didn't leave room to actually browse or read results. macOS has
/// no native contact-picker view controller outside of Mac Catalyst/UIKit
/// (CNContactPickerViewController is iOS/Catalyst-only), so this is our own
/// SwiftUI list, just given a proper window instead of a cramped inline box.
final class ContactPickerWindowManager {
    static let shared = ContactPickerWindowManager()

    private var window: NSWindow?
    private var completion: ((ContactMatch?) -> Void)?
    private var didFinish = false

    private init() {}

    func show(completion: @escaping (ContactMatch?) -> Void) {
        finish(with: nil)
        didFinish = false
        self.completion = completion

        let contentView = ContactPickerWindowContent { [weak self] match in
            self?.finish(with: match)
        }
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Choose a Contact"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 340, height: 480))
        window.minSize = NSSize(width: 300, height: 360)
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            // NotificationCenter's closure type isn't statically @MainActor
            // even with queue: .main — but queue: .main guarantees this body
            // only ever runs on the main thread, so assumeIsolated is safe.
            MainActor.assumeIsolated {
                self?.finish(with: nil)
            }
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    private func finish(with match: ContactMatch?) {
        guard !didFinish else { return }
        didFinish = true

        window?.close()
        window = nil

        let callback = completion
        completion = nil
        callback?(match)
    }
}

struct ContactPickerWindowContent: View {
    let onSelect: (ContactMatch?) -> Void

    @State private var searchText = ""
    @State private var results: [ContactMatch] = []
    @State private var authorizationDenied = false
    @State private var isLoading = true

    var body: some View {
        Group {
            if authorizationDenied {
                deniedView
            } else {
                VStack(spacing: 0) {
                    TextField("Search Contacts", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .padding(14)
                        .onChange(of: searchText) { _, newValue in
                            runSearch(newValue)
                        }

                    Divider()

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if results.isEmpty {
                        Text("No matches")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(results) { contact in
                            Button {
                                onSelect(contact)
                            } label: {
                                contactRow(contact)
                            }
                            .buttonStyle(.plain)
                        }
                        .listStyle(.inset)
                    }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 360)
        .onAppear { requestAndSearch() }
    }

    private func contactRow(_ contact: ContactMatch) -> some View {
        HStack(spacing: 10) {
            initialsCircle(for: contact)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                if !contact.displaySubtitle.isEmpty {
                    Text(contact.displaySubtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var deniedView: some View {
        VStack(spacing: 10) {
            Text("Contacts Access is Off")
                .font(.system(size: 14, weight: .semibold))
            Text("Snipster needs Contacts access to autofill this field. Enable it in System Settings > Privacy & Security > Contacts.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func requestAndSearch() {
        Task {
            let granted = await ContactAutofillService.requestAccess()
            await MainActor.run {
                authorizationDenied = !granted
                isLoading = false
            }
            if granted {
                runSearch(searchText)
            }
        }
    }

    private func runSearch(_ query: String) {
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let matches = ContactAutofillService.search(query)
            await MainActor.run {
                results = matches
                isLoading = false
            }
        }
    }

    private func initialsCircle(for contact: ContactMatch) -> some View {
        Circle()
            .fill(color(for: contact.id))
            .frame(width: 28, height: 28)
            .overlay(
                Text(initials(for: contact.displayName))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private func initials(for name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private func color(for id: String) -> Color {
        let palette: [Color] = [.orange, .blue, .pink, .green, .purple, .teal]
        let index = abs(id.hashValue) % palette.count
        return palette[index]
    }
}
