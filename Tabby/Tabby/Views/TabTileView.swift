// TabTileView.swift
// Tabby
//
// A single tile in the Mission Control grid representing one browser tab.
// Shows the favicon, title, URL preview, and browser indicator.

import SwiftUI
import WebKit

// MARK: - WebPreviewView

/// A small non-interactive WKWebView for previewing tab content.
/// Zooms out to fit the page and disables all scrolling/interaction.
/// Includes a load timeout and blocks cross-origin redirects (login pages).
struct WebPreviewView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsMagnification = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // Disable scrolling and interaction — purely a thumbnail
        if let scrollView = webView.enclosingScrollView {
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        context.coordinator.originalHost = url.host
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 5)
        webView.load(request)

        // Hard timeout: stop loading after 5 seconds regardless
        context.coordinator.timeoutWork?.cancel()
        let work = DispatchWorkItem { [weak webView] in
            webView?.stopLoading()
        }
        context.coordinator.timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.timeoutWork?.cancel()
        webView.stopLoading()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var loadedURL: URL?
        var originalHost: String?
        var timeoutWork: DispatchWorkItem?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            timeoutWork?.cancel()
            let css = """
            document.documentElement.style.zoom = '0.4';
            document.body.style.overflow = 'hidden';
            document.documentElement.style.overflow = 'hidden';
            """
            webView.evaluateJavaScript(css, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            timeoutWork?.cancel()
        }

        /// Block cross-origin redirects (e.g. login/SSO redirects) to prevent
        /// the preview from getting stuck loading an auth page.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .other || navigationAction.navigationType == .linkActivated,
               let navHost = navigationAction.request.url?.host,
               let origHost = originalHost,
               navHost != origHost {
                // Cross-origin redirect — likely SSO/login. Cancel it.
                decisionHandler(.cancel)
                webView.stopLoading()
                return
            }
            decisionHandler(.allow)
        }
    }
}

/// URLs with these schemes cannot be loaded in WKWebView and would
/// trigger system "no application set to open" dialogs.
private let nonPreviewableSchemes: Set<String> = [
    "chrome", "chrome-extension", "edge", "about",
    "safari-web-extension", "file", "data", "blob",
    "brave", "vivaldi", "opera", "arc"
]

/// Whether a URL string points to a page we can safely preview in WKWebView.
private func isPreviewableURL(_ urlString: String) -> Bool {
    guard let url = URL(string: urlString),
          let scheme = url.scheme?.lowercased() else {
        return false
    }
    return !nonPreviewableSchemes.contains(scheme)
}

// MARK: - TabTileView

struct TabTileView: View {
    let tab: BrowserTab
    let onActivate: () -> Void

    /// Whether the mouse is hovering over this tile
    @State private var isHovered = false

    /// Whether to show the preview popover
    @State private var showPreview = false

    /// Timer for the hover delay
    @State private var hoverTimer: Timer?

    var body: some View {
        Button(action: onActivate) {
            VStack(alignment: .leading, spacing: 6) {

                // Top row: favicon + browser label
                HStack(spacing: 8) {
                    // Favicon
                    faviconView
                        .frame(width: 20, height: 20)

                    Spacer()

                    // Browser label
                    Text(tab.browser == .chrome ? "Chrome" : "Edge")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(browserColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(browserColor.opacity(0.12))
                        .cornerRadius(4)
                }

                // Title
                Text(tab.title.isEmpty ? "Untitled" : tab.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // URL (truncated)
                Text(displayURL)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 120, alignment: .topLeading)
            .background(tileBackground)
            .cornerRadius(10)
            .shadow(
                color: isHovered ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.1),
                radius: isHovered ? 8 : 4,
                x: 0,
                y: isHovered ? 4 : 2
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                // 1.5s delay before showing preview to avoid accidental triggers
                hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                    DispatchQueue.main.async {
                        // Double-check still hovered before showing
                        if isHovered {
                            showPreview = true
                        }
                    }
                }
            } else {
                hoverTimer?.invalidate()
                hoverTimer = nil
                showPreview = false
            }
        }
        .popover(isPresented: $showPreview, arrowEdge: .bottom) {
            if isPreviewableURL(tab.url), let url = URL(string: tab.url) {
                WebPreviewView(url: url)
                    .frame(width: 300, height: 200)
            } else {
                Text("No preview available")
                    .frame(width: 200, height: 100)
                    .foregroundColor(.secondary)
            }
        }
        .help(tab.url) // Tooltip showing full URL
    }

    // MARK: - Subviews

    /// Renders the favicon from base64 data, URL, or shows a fallback icon.
    @ViewBuilder
    private var faviconView: some View {
        if let faviconData = tab.favicon,
           !faviconData.isEmpty,
           let imageData = extractBase64ImageData(from: faviconData),
           let nsImage = NSImage(data: imageData) {
            // Got a valid base64 data URI from the extension
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let faviconData = tab.favicon,
                  !faviconData.isEmpty,
                  faviconData.hasPrefix("http"),
                  let url = URL(string: faviconData) {
            // Favicon is a URL — load it asynchronously
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fit)
                default:
                    Image(systemName: "globe")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
        } else {
            Image(systemName: "globe")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }

    /// Background color/material for the tile
    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isHovered ? Color.accentColor.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
    }

    /// Browser-specific accent color
    private var browserColor: Color {
        switch tab.browser {
        case .chrome:  return .red
        case .edge:    return .blue
        }
    }

    /// Shortened URL for display (strips protocol, www prefix)
    private var displayURL: String {
        var url = tab.url
        url = url.replacingOccurrences(of: "https://", with: "")
        url = url.replacingOccurrences(of: "http://", with: "")
        if url.hasPrefix("www.") {
            url = String(url.dropFirst(4))
        }
        return url
    }

    // MARK: - Helpers

    /// Extract raw image data from a base64 data URI string.
    /// Input format: "data:image/png;base64,iVBORw0KGgo..."
    private func extractBase64ImageData(from dataURI: String) -> Data? {
        let base64String: String
        if let commaIndex = dataURI.firstIndex(of: ",") {
            base64String = String(dataURI[dataURI.index(after: commaIndex)...])
        } else {
            base64String = dataURI
        }

        // Try standard decoding first
        if let data = Data(base64Encoded: base64String) {
            return data
        }

        // Handle URL-safe base64 and missing padding
        var cleaned = base64String
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Add padding if needed
        let remainder = cleaned.count % 4
        if remainder > 0 {
            cleaned += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: cleaned)
    }
}
