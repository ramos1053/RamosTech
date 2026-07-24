//
//  CopyPathService.swift
//  Snipster
//

import AppKit
import Combine

/// Provides the "Copy Path" Finder service: right-click a file, choose
/// Services > Copy Path, and its POSIX path is copied to the clipboard as
/// plain text.
///
/// macOS builds the Services menu entry from the static Info.plist
/// declaration, so there's no supported way to make the menu item itself
/// disappear when `isEnabled` is off. Instead, the provider stays registered
/// and the handler declines. The `error` out-parameter is set for
/// completeness, but macOS doesn't surface it visibly for a send-only
/// (no NSReturnTypes) service, so an explicit alert is shown instead.
@MainActor
final class CopyPathService: NSObject, ObservableObject {
    static let shared = CopyPathService()

    private static let enabledKey = "snipster.copyPathService.enabled"

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
        }
    }

    private override init() {
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        super.init()
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
    }

    /// Entry point registered in Info.plist under NSServices -> NSMessage "copyPath".
    @objc func copyPath(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard isEnabled else {
            error.pointee = "Copy Path is disabled. Enable it in Snipster's Settings > Finder Integration." as NSString
            InfoAlertWindow.show(title: "Copy Path is Disabled",
                                  message: "Enable \"Copy Path\" in Finder from Snipster's Settings > Finder Integration to use this action.")
            return
        }

        let urls = pboard.readObjects(forClasses: [NSURL.self],
                                       options: [.urlReadingFileURLsOnly: true]) as? [URL]

        guard let urls, !urls.isEmpty else {
            error.pointee = "Copy Path: no file was selected." as NSString
            return
        }

        let paths = urls.map(\.path).joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths, forType: .string)
    }
}
