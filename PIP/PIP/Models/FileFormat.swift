import Foundation
import AppKit

/// Supported file formats and their handlers
enum FileFormat: String, CaseIterable {
    case plainText = "txt"
    case shell = "sh"
    case bash = "bash"
    case zsh = "zsh"
    case python = "py"
    case ruby = "rb"
    case perl = "pl"
    case javascript = "js"
    case php = "php"

    var displayName: String {
        switch self {
        case .plainText: return "Plain Text"
        case .shell: return "Shell Script"
        case .bash: return "Bash Script"
        case .zsh: return "Zsh Script"
        case .python: return "Python Script"
        case .ruby: return "Ruby Script"
        case .perl: return "Perl Script"
        case .javascript: return "JavaScript"
        case .php: return "PHP Script"
        }
    }

    var utType: String {
        switch self {
        case .plainText: return "public.plain-text"
        case .shell, .bash, .zsh: return "public.shell-script"
        case .python: return "public.python-script"
        case .ruby: return "public.ruby-script"
        case .perl: return "public.perl-script"
        case .javascript: return "public.script"
        case .php: return "public.php-script"
        }
    }

    var fileExtension: String {
        rawValue
    }

    var supportsFormatting: Bool {
        false
    }

    var isExecutable: Bool {
        switch self {
        case .shell, .bash, .zsh, .python, .ruby, .perl, .javascript, .php:
            return true
        case .plainText:
            return false
        }
    }

    static func from(fileExtension ext: String) -> FileFormat {
        FileFormat(rawValue: ext.lowercased()) ?? .plainText
    }

    static func from(url: URL) -> FileFormat {
        let ext = url.pathExtension.lowercased()
        return from(fileExtension: ext)
    }
}

/// Handles import/export for different file formats
actor FileFormatHandler {

    // MARK: - Import

    func importFile(from url: URL, encoding: String.Encoding? = nil) async throws -> (content: String, detectedEncoding: String.Encoding, format: FileFormat) {
        _ = FileFormat.from(url: url)
        return try await importPlainText(from: url, encoding: encoding)
    }

    private func importPlainText(from url: URL, encoding: String.Encoding?) async throws -> (String, String.Encoding, FileFormat) {
        let data = try Data(contentsOf: url)

        let detectedEncoding = encoding ?? detectEncoding(data: data)

        guard let content = String(data: data, encoding: detectedEncoding) else {
            throw NSError(domain: "FileFormatHandler", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not decode file with encoding \(detectedEncoding)"])
        }

        let format = FileFormat.from(url: url)
        return (content, detectedEncoding, format)
    }


    // MARK: - Export

    func exportFile(content: String, to url: URL, format: FileFormat, encoding: String.Encoding = .utf8) async throws {
        try await exportPlainText(content: content, to: url, encoding: encoding)
    }

    private func exportPlainText(content: String, to url: URL, encoding: String.Encoding) async throws {
        guard let data = content.data(using: encoding) else {
            throw NSError(domain: "FileFormatHandler", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not encode content"])
        }

        try data.write(to: url, options: .atomic)

        // Make shell scripts executable
        if FileFormat.from(url: url).isExecutable {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }


    // MARK: - Encoding Detection

    private func detectEncoding(data: Data) -> String.Encoding {
        // Check for BOM
        if data.count >= 3 {
            let bom = data.prefix(3)
            if bom == Data([0xEF, 0xBB, 0xBF]) {
                return .utf8
            }
        }

        if data.count >= 2 {
            let bom = data.prefix(2)
            if bom == Data([0xFE, 0xFF]) {
                return .utf16BigEndian
            }
            if bom == Data([0xFF, 0xFE]) {
                return .utf16LittleEndian
            }
        }

        // Try UTF-8
        if String(data: data, encoding: .utf8) != nil {
            return .utf8
        }

        // Fall back to ISO Latin 1
        return .isoLatin1
    }
}
