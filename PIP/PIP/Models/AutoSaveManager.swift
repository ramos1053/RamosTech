import Foundation
import Combine

/// Manages automatic saving of documents
@MainActor
final class AutoSaveManager: ObservableObject {
    static let shared = AutoSaveManager()

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let preferences = AppPreferences.shared

    @Published private(set) var lastAutoSaveDate: Date?
    @Published private(set) var isAutoSaving: Bool = false

    private init() {
        setupTimer()

        // Observe preference changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupTimer()
            }
            .store(in: &cancellables)
    }

    private func setupTimer() {
        // Cancel existing timer
        timer?.invalidate()
        timer = nil

        // Only set up timer if auto-save is enabled AND backup is enabled
        guard preferences.autoSave && preferences.createBackupOnSave else { return }

        let interval = TimeInterval(preferences.autoSaveInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performAutoSave()
            }
        }
    }

    private func performAutoSave() {
        guard preferences.autoSave && preferences.createBackupOnSave, !isAutoSaving else { return }

        isAutoSaving = true
        NotificationCenter.default.post(name: .autoSaveTriggered, object: nil)
        lastAutoSaveDate = Date()
        isAutoSaving = false
    }

    /// Create a backup of the file before saving
    func createBackup(for url: URL) throws {
        guard preferences.createBackupOnSave else { return }

        let fileManager = FileManager.default
        let backupDirectory = url.deletingLastPathComponent().appendingPathComponent(".backups", isDirectory: true)

        // Create backup directory if needed
        if !fileManager.fileExists(atPath: backupDirectory.path) {
            try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        }

        // Create backup filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let backupName = "\(url.deletingPathExtension().lastPathComponent)_\(timestamp).\(url.pathExtension)"
        let backupURL = backupDirectory.appendingPathComponent(backupName)

        // Copy file to backup
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.copyItem(at: url, to: backupURL)
        }

        // Clean up old backups (keep last 10)
        cleanupOldBackups(in: backupDirectory, keeping: 10)
    }

    private func cleanupOldBackups(in directory: URL, keeping maxCount: Int) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) else {
            return
        }

        // Sort by creation date
        let sortedFiles = files.sorted { file1, file2 in
            let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 > date2
        }

        // Remove files beyond the max count
        for file in sortedFiles.dropFirst(maxCount) {
            try? fileManager.removeItem(at: file)
        }
    }

    func stopAutoSave() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}

