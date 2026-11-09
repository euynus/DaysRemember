import Foundation

/// What 数据与同步 is busy with, one thing at a time: a backup being read can't overlap iCloud data
/// being deleted, the restore a read backup leads to waits for its confirmation, and an export
/// holds its file only while the exporter is open. Its nine other confirmations stay with the
/// controls that open them; each is modal, so they can't overlap either.
enum DataManagementActivity {
    case idle
    /// Reading and checking the backup file chosen to restore from.
    case readingBackup
    /// A backup has been read; restoring it waits for the user's confirmation.
    case confirmingRestore(DayBackup)
    /// Deleting this app's data from iCloud.
    case deletingCloudData
    /// The exporter is saving `document` as `filename`.
    case exporting(BackupDocument, filename: String)

    var isIdle: Bool {
        if case .idle = self { true } else { false }
    }

    /// Work under way that shows its progress in the form: reading a backup, or deleting iCloud data.
    /// Starting either, turning sync on or off, or exporting waits until it ends.
    var isBusy: Bool {
        switch self {
        case .readingBackup, .deletingCloudData: true
        case .idle, .confirmingRestore, .exporting: false
        }
    }

    /// The backup waiting for the user to confirm its restore.
    var pendingRestore: DayBackup? {
        if case .confirmingRestore(let backup) = self { backup } else { nil }
    }

    var exportDocument: BackupDocument? {
        if case .exporting(let document, _) = self { document } else { nil }
    }

    var exportFilename: String? {
        if case .exporting(_, let filename) = self { filename } else { nil }
    }

    // MARK: - Restoring a backup file

    /// Starts reading a chosen backup; false while something else is under way.
    mutating func startReading() -> Bool {
        guard isIdle else { return false }
        self = .readingBackup
        return true
    }

    /// The read ended: a backup waits for confirmation; an error is thrown for the form to show.
    mutating func finishReading(_ result: Result<DayBackup, any Error>) throws {
        guard case .readingBackup = self else { return }
        switch result {
        case .success(let backup):
            self = .confirmingRestore(backup)
        case .failure(let error):
            self = .idle
            throw error
        }
    }

    /// The user confirmed the restore: the backup to restore, once.
    mutating func confirmRestore() -> DayBackup? {
        guard let backup = pendingRestore else { return nil }
        self = .idle
        return backup
    }

    /// The confirmation closed without restoring.
    mutating func cancelRestore() {
        if pendingRestore != nil { self = .idle }
    }

    // MARK: - Deleting iCloud data

    /// Starts deleting iCloud data; false while something else is under way.
    mutating func startDeletingCloudData() -> Bool {
        guard isIdle else { return false }
        self = .deletingCloudData
        return true
    }

    mutating func finishDeletingCloudData() {
        if case .deletingCloudData = self { self = .idle }
    }

    // MARK: - Exporting

    /// Opens the exporter for `document`; false while something else is under way.
    mutating func startExport(_ document: BackupDocument, filename: String) -> Bool {
        guard isIdle else { return false }
        self = .exporting(document, filename: filename)
        return true
    }

    /// The exporter closed, saved or not.
    mutating func finishExport() {
        if exportDocument != nil { self = .idle }
    }
}
