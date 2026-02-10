import SwiftUI
import AppKit

/// Editor theme with colors and appearance settings
struct EditorTheme: Codable, Identifiable {
    let id: String
    let name: String
    let backgroundColor: CodableColor
    let textColor: CodableColor
    let cursorColor: CodableColor
    let selectionColor: CodableColor
    let lineNumberColor: CodableColor
    let lineNumberBackgroundColor: CodableColor
    let commentColor: CodableColor
    let keywordColor: CodableColor
    let stringColor: CodableColor
    let numberColor: CodableColor
    let operatorColor: CodableColor
    let functionColor: CodableColor
    let opacity: Double

    /// Codable wrapper for NSColor
    struct CodableColor: Codable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        init(color: NSColor) {
            let rgb = color.usingColorSpace(.sRGB) ?? color
            self.red = rgb.redComponent
            self.green = rgb.greenComponent
            self.blue = rgb.blueComponent
            self.alpha = rgb.alphaComponent
        }

        var nsColor: NSColor {
            NSColor(red: red, green: green, blue: blue, alpha: alpha)
        }

        var color: Color {
            Color(nsColor: nsColor)
        }
    }
}

// MARK: - Built-in Themes

extension EditorTheme {

    /// Default light theme
    static let defaultLight = EditorTheme(
        id: "default-light",
        name: "Default Light",
        backgroundColor: CodableColor(color: .white),
        textColor: CodableColor(color: .black),
        cursorColor: CodableColor(color: .black),
        selectionColor: CodableColor(color: NSColor.selectedTextBackgroundColor),
        lineNumberColor: CodableColor(color: .gray),
        lineNumberBackgroundColor: CodableColor(color: NSColor(white: 0.95, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.67, green: 0.0, blue: 0.67, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.77, green: 0.13, blue: 0.09, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.11, green: 0.0, blue: 0.81, alpha: 1.0)),
        operatorColor: CodableColor(color: .darkGray),
        functionColor: CodableColor(color: NSColor(red: 0.25, green: 0.33, blue: 0.75, alpha: 1.0)),
        opacity: 1.0
    )

    /// Default dark theme (Basic)
    static let defaultDark = EditorTheme(
        id: "default-dark",
        name: "Basic Dark",
        backgroundColor: CodableColor(color: NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(white: 0.9, alpha: 1.0)),
        cursorColor: CodableColor(color: .white),
        selectionColor: CodableColor(color: NSColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 0.5)),
        lineNumberColor: CodableColor(color: NSColor(white: 0.5, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.4, green: 0.7, blue: 0.4, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.86, green: 0.44, blue: 0.87, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.98, green: 0.53, blue: 0.48, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.68, green: 0.85, blue: 0.90, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(white: 0.8, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.47, green: 0.67, blue: 0.99, alpha: 1.0)),
        opacity: 1.0
    )

    /// Homebrew theme (green on black)
    static let homebrew = EditorTheme(
        id: "homebrew",
        name: "Homebrew",
        backgroundColor: CodableColor(color: .black),
        textColor: CodableColor(color: NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)),
        cursorColor: CodableColor(color: NSColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)),
        selectionColor: CodableColor(color: NSColor(red: 0.0, green: 0.4, blue: 0.0, alpha: 0.5)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.0, green: 0.6, blue: 0.0, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(white: 0.05, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.6, green: 1.0, blue: 0.6, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 0.0, green: 0.9, blue: 0.0, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.4, green: 1.0, blue: 0.4, alpha: 1.0)),
        opacity: 0.95
    )

    /// Pro theme (like Terminal Pro)
    static let pro = EditorTheme(
        id: "pro",
        name: "Pro",
        backgroundColor: CodableColor(color: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1.0)),
        cursorColor: CodableColor(color: .white),
        selectionColor: CodableColor(color: NSColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.5)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.03, green: 0.03, blue: 0.03, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.45, green: 0.48, blue: 0.51, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.8, green: 0.47, blue: 0.86, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.99, green: 0.48, blue: 0.42, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.85, green: 0.85, blue: 0.67, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.40, green: 0.71, blue: 0.99, alpha: 1.0)),
        opacity: 0.90
    )

    /// Ocean theme (blue tones)
    static let ocean = EditorTheme(
        id: "ocean",
        name: "Ocean",
        backgroundColor: CodableColor(color: NSColor(red: 0.09, green: 0.11, blue: 0.15, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(red: 0.78, green: 0.91, blue: 0.96, alpha: 1.0)),
        cursorColor: CodableColor(color: NSColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0)),
        selectionColor: CodableColor(color: NSColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 0.5)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.4, green: 0.6, blue: 0.7, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.5, green: 0.9, blue: 0.8, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.9, green: 0.7, blue: 0.5, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 0.7, green: 0.85, blue: 0.95, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.45, green: 0.75, blue: 0.98, alpha: 1.0)),
        opacity: 0.95
    )

    /// Red Sands theme (warm colors)
    static let redSands = EditorTheme(
        id: "red-sands",
        name: "Red Sands",
        backgroundColor: CodableColor(color: NSColor(red: 0.14, green: 0.09, blue: 0.09, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(red: 0.95, green: 0.91, blue: 0.86, alpha: 1.0)),
        cursorColor: CodableColor(color: NSColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0)),
        selectionColor: CodableColor(color: NSColor(red: 0.5, green: 0.2, blue: 0.2, alpha: 0.5)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.6, green: 0.4, blue: 0.4, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.11, green: 0.06, blue: 0.06, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.7, green: 0.5, blue: 0.4, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.9, green: 0.8, blue: 0.5, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.9, green: 0.7, blue: 0.4, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 0.9, green: 0.85, blue: 0.8, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.95, green: 0.75, blue: 0.55, alpha: 1.0)),
        opacity: 0.95
    )

    /// Silver Aerogel theme (light with transparency)
    static let silverAerogel = EditorTheme(
        id: "silver-aerogel",
        name: "Silver Aerogel",
        backgroundColor: CodableColor(color: NSColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)),
        cursorColor: CodableColor(color: NSColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 1.0)),
        selectionColor: CodableColor(color: NSColor(red: 0.6, green: 0.7, blue: 0.9, alpha: 0.4)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.45, green: 0.5, blue: 0.55, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.5, green: 0.3, blue: 0.7, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.7, green: 0.3, blue: 0.3, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.3, green: 0.4, blue: 0.7, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 1.0)),
        opacity: 0.85
    )

    /// Monokai theme (popular dark theme)
    static let monokai = EditorTheme(
        id: "monokai",
        name: "Monokai",
        backgroundColor: CodableColor(color: NSColor(red: 0.16, green: 0.16, blue: 0.14, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1.0)),
        cursorColor: CodableColor(color: NSColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1.0)),
        selectionColor: CodableColor(color: NSColor(red: 0.25, green: 0.25, blue: 0.22, alpha: 1.0)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.55, green: 0.55, blue: 0.50, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.13, green: 0.13, blue: 0.11, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.45, green: 0.45, blue: 0.41, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.98, green: 0.15, blue: 0.45, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.90, green: 0.86, blue: 0.45, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.68, green: 0.51, blue: 1.0, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 0.98, green: 0.15, blue: 0.45, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.65, green: 0.89, blue: 0.18, alpha: 1.0)),
        opacity: 1.0
    )

    /// Dracula theme (popular dark theme)
    static let dracula = EditorTheme(
        id: "dracula",
        name: "Dracula",
        backgroundColor: CodableColor(color: NSColor(red: 0.16, green: 0.16, blue: 0.21, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1.0)),
        cursorColor: CodableColor(color: NSColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1.0)),
        selectionColor: CodableColor(color: NSColor(red: 0.27, green: 0.29, blue: 0.39, alpha: 1.0)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.51, green: 0.53, blue: 0.63, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.13, green: 0.13, blue: 0.18, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.38, green: 0.45, blue: 0.64, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 1.0, green: 0.47, blue: 0.78, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.95, green: 0.98, blue: 0.55, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.74, green: 0.58, blue: 0.98, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 1.0, green: 0.47, blue: 0.78, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.31, green: 0.98, blue: 0.48, alpha: 1.0)),
        opacity: 1.0
    )

    /// Solarized Light theme
    static let solarizedLight = EditorTheme(
        id: "solarized-light",
        name: "Solarized Light",
        backgroundColor: CodableColor(color: NSColor(red: 0.99, green: 0.96, blue: 0.89, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(red: 0.40, green: 0.48, blue: 0.51, alpha: 1.0)),
        cursorColor: CodableColor(color: NSColor(red: 0.40, green: 0.48, blue: 0.51, alpha: 1.0)),
        selectionColor: CodableColor(color: NSColor(red: 0.93, green: 0.91, blue: 0.84, alpha: 1.0)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.58, green: 0.63, blue: 0.63, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.93, green: 0.91, blue: 0.84, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.58, green: 0.63, blue: 0.63, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.51, green: 0.58, blue: 0.0, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.16, green: 0.63, blue: 0.60, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.86, green: 0.20, blue: 0.18, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 0.40, green: 0.48, blue: 0.51, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1.0)),
        opacity: 1.0
    )

    /// Solarized Dark theme
    static let solarizedDark = EditorTheme(
        id: "solarized-dark",
        name: "Solarized Dark",
        backgroundColor: CodableColor(color: NSColor(red: 0.0, green: 0.17, blue: 0.21, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1.0)),
        cursorColor: CodableColor(color: NSColor(red: 0.58, green: 0.63, blue: 0.63, alpha: 1.0)),
        selectionColor: CodableColor(color: NSColor(red: 0.03, green: 0.21, blue: 0.26, alpha: 1.0)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.36, green: 0.43, blue: 0.44, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.03, green: 0.21, blue: 0.26, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.36, green: 0.43, blue: 0.44, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.51, green: 0.58, blue: 0.0, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.16, green: 0.63, blue: 0.60, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.86, green: 0.20, blue: 0.18, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.15, green: 0.55, blue: 0.82, alpha: 1.0)),
        opacity: 1.0
    )

    /// Nord theme (cool blue palette)
    static let nord = EditorTheme(
        id: "nord",
        name: "Nord",
        backgroundColor: CodableColor(color: NSColor(red: 0.18, green: 0.20, blue: 0.25, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(red: 0.85, green: 0.87, blue: 0.91, alpha: 1.0)),
        cursorColor: CodableColor(color: NSColor(red: 0.85, green: 0.87, blue: 0.91, alpha: 1.0)),
        selectionColor: CodableColor(color: NSColor(red: 0.26, green: 0.30, blue: 0.37, alpha: 1.0)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.36, green: 0.42, blue: 0.53, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.15, green: 0.17, blue: 0.21, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.36, green: 0.42, blue: 0.53, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.51, green: 0.63, blue: 0.76, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.64, green: 0.75, blue: 0.54, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.71, green: 0.56, blue: 0.68, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 0.51, green: 0.63, blue: 0.76, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.53, green: 0.75, blue: 0.82, alpha: 1.0)),
        opacity: 1.0
    )

    /// Gruvbox Dark theme (retro groove)
    static let gruvboxDark = EditorTheme(
        id: "gruvbox-dark",
        name: "Gruvbox Dark",
        backgroundColor: CodableColor(color: NSColor(red: 0.16, green: 0.16, blue: 0.13, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(red: 0.92, green: 0.86, blue: 0.70, alpha: 1.0)),
        cursorColor: CodableColor(color: NSColor(red: 0.92, green: 0.86, blue: 0.70, alpha: 1.0)),
        selectionColor: CodableColor(color: NSColor(red: 0.26, green: 0.26, blue: 0.22, alpha: 1.0)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.51, green: 0.48, blue: 0.42, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.13, green: 0.13, blue: 0.10, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.51, green: 0.48, blue: 0.42, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.98, green: 0.54, blue: 0.38, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.72, green: 0.73, blue: 0.15, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.83, green: 0.60, blue: 0.53, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 0.92, green: 0.86, blue: 0.70, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.56, green: 0.75, blue: 0.49, alpha: 1.0)),
        opacity: 1.0
    )

    /// One Dark theme (Atom editor)
    static let oneDark = EditorTheme(
        id: "one-dark",
        name: "One Dark",
        backgroundColor: CodableColor(color: NSColor(red: 0.16, green: 0.17, blue: 0.21, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(red: 0.67, green: 0.71, blue: 0.76, alpha: 1.0)),
        cursorColor: CodableColor(color: NSColor(red: 0.67, green: 0.71, blue: 0.76, alpha: 1.0)),
        selectionColor: CodableColor(color: NSColor(red: 0.23, green: 0.26, blue: 0.31, alpha: 1.0)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.37, green: 0.41, blue: 0.47, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.13, green: 0.14, blue: 0.18, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.37, green: 0.41, blue: 0.47, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.78, green: 0.47, blue: 0.78, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.60, green: 0.76, blue: 0.48, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.84, green: 0.60, blue: 0.47, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 0.33, green: 0.68, blue: 0.76, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.38, green: 0.67, blue: 0.98, alpha: 1.0)),
        opacity: 1.0
    )

    /// GitHub Light theme
    static let githubLight = EditorTheme(
        id: "github-light",
        name: "GitHub Light",
        backgroundColor: CodableColor(color: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(red: 0.14, green: 0.16, blue: 0.18, alpha: 1.0)),
        cursorColor: CodableColor(color: NSColor(red: 0.14, green: 0.16, blue: 0.18, alpha: 1.0)),
        selectionColor: CodableColor(color: NSColor(red: 0.71, green: 0.84, blue: 0.99, alpha: 1.0)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.53, green: 0.57, blue: 0.62, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.42, green: 0.46, blue: 0.51, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.82, green: 0.10, blue: 0.33, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.02, green: 0.37, blue: 0.68, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 0.0, green: 0.40, blue: 0.66, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 0.14, green: 0.16, blue: 0.18, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.48, green: 0.22, blue: 0.82, alpha: 1.0)),
        opacity: 1.0
    )

    /// Tokyo Night theme
    static let tokyoNight = EditorTheme(
        id: "tokyo-night",
        name: "Tokyo Night",
        backgroundColor: CodableColor(color: NSColor(red: 0.09, green: 0.10, blue: 0.14, alpha: 1.0)),
        textColor: CodableColor(color: NSColor(red: 0.66, green: 0.70, blue: 0.81, alpha: 1.0)),
        cursorColor: CodableColor(color: NSColor(red: 0.66, green: 0.70, blue: 0.81, alpha: 1.0)),
        selectionColor: CodableColor(color: NSColor(red: 0.16, green: 0.19, blue: 0.28, alpha: 1.0)),
        lineNumberColor: CodableColor(color: NSColor(red: 0.36, green: 0.40, blue: 0.51, alpha: 1.0)),
        lineNumberBackgroundColor: CodableColor(color: NSColor(red: 0.07, green: 0.08, blue: 0.11, alpha: 1.0)),
        commentColor: CodableColor(color: NSColor(red: 0.34, green: 0.42, blue: 0.55, alpha: 1.0)),
        keywordColor: CodableColor(color: NSColor(red: 0.48, green: 0.61, blue: 0.89, alpha: 1.0)),
        stringColor: CodableColor(color: NSColor(red: 0.56, green: 0.78, blue: 0.49, alpha: 1.0)),
        numberColor: CodableColor(color: NSColor(red: 1.0, green: 0.63, blue: 0.47, alpha: 1.0)),
        operatorColor: CodableColor(color: NSColor(red: 0.48, green: 0.61, blue: 0.89, alpha: 1.0)),
        functionColor: CodableColor(color: NSColor(red: 0.45, green: 0.71, blue: 0.93, alpha: 1.0)),
        opacity: 1.0
    )

    /// All available themes
    static let allThemes: [EditorTheme] = [
        .defaultLight,
        .defaultDark,
        .monokai,
        .dracula,
        .solarizedLight,
        .solarizedDark,
        .nord,
        .gruvboxDark,
        .oneDark,
        .githubLight,
        .tokyoNight,
        .homebrew,
        .pro,
        .ocean,
        .redSands,
        .silverAerogel
    ]

    /// Get theme by ID
    static func theme(withID id: String) -> EditorTheme? {
        allThemes.first { $0.id == id }
    }
}
