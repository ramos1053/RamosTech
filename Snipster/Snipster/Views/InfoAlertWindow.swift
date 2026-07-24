//
//  InfoAlertWindow.swift
//  Snipster
//

import SwiftUI
import AppKit

/// A minimal centered info alert — icon, bold title, message, one button —
/// all built and laid out by us rather than by NSAlert. A standalone
/// app-modal NSAlert (no parent window to sheet against) renders in
/// AppKit's classic icon-top-left layout, and fighting that via
/// accessoryView tricks didn't actually center anything (the accessory
/// view kept the old icon-gutter offset and got clipped). Same borderless
/// floating-panel family as TemplateInputWindow/SpotlightWindow.
final class InfoAlertPanel: NSPanel {
    convenience init(contentViewController: NSViewController, size: NSSize) {
        self.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.contentViewController = contentViewController
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .modalPanel
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct InfoAlertContentView: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 64, height: 64)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onDismiss) {
                // background/clipShape/contentShape all live inside the
                // label (not chained after the Button) so the capsule's
                // full drawn area — not just the "OK" text glyphs — is
                // part of the button's hit-test region.
                Text("OK")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Capsule())
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 300)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
    }
}

enum InfoAlertWindow {
    /// Shows a centered info alert app-modally and blocks until dismissed —
    /// matching the blocking behavior the old NSAlert.runModal() call had.
    @MainActor
    static func show(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let contentView = InfoAlertContentView(title: title, message: message) {
            NSApp.stopModal()
        }
        let hostingController = NSHostingController(rootView: contentView)

        let panel = InfoAlertPanel(contentViewController: hostingController, size: NSSize(width: 300, height: 200))
        panel.setContentSize(hostingController.view.fittingSize)
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        NSApp.runModal(for: panel)

        panel.orderOut(nil)
        panel.close()
    }
}
