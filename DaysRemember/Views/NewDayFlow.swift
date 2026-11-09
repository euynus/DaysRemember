import Foundation

/// The new day's editor that `RootTabView` presents, asked for by 日子's + button, a calendar cell,
/// a category's list, a link or onboarding. Onboarding's first day on a new device waits for
/// iCloud's first download, which may bring the library, and opens only if the library is still
/// empty after it.
enum NewDayFlow: Equatable {
    case idle
    /// Onboarding's first day, waiting for iCloud's first download.
    case awaitingFirstDownload
    /// The editor is open.
    case editing(NewDayRequest)
    /// The editor has been dismissed and is leaving the screen; `addedDay` says whether it saved.
    case closing(addedDay: Bool)

    /// Onboarding's first day opens at once, unless iCloud's first download is still pending.
    init(firstDay: Bool, downloadPending: Bool) {
        if !firstDay { self = .idle }
        else if downloadPending { self = .awaitingFirstDownload }
        else { self = .editing(NewDayRequest()) }
    }

    /// The open editor's request.
    var request: NewDayRequest? {
        if case .editing(let request) = self { request } else { nil }
    }

    /// Opens the editor in `categoryID` or on `date`; it ends a wait for the first download, which
    /// then opens nothing more. An editor already open keeps its draft.
    mutating func open(categoryID: String? = nil, date: Date? = nil) {
        guard request == nil else { return }
        self = .editing(NewDayRequest(categoryID: categoryID, date: date))
    }

    /// iCloud's first download ended: a first day still waiting for it opens if the library is empty.
    mutating func firstDownloadEnded(libraryIsEmpty: Bool) {
        guard self == .awaitingFirstDownload else { return }
        self = libraryIsEmpty ? .editing(NewDayRequest()) : .idle
    }

    /// The editor was dismissed, saved or not; `contains` says whether the library holds a day.
    mutating func editorDismissed(libraryContains contains: (String) -> Bool) {
        guard let request else { return }
        self = .closing(addedDay: contains(request.id))
    }

    /// The editor has gone. True when it added its day: a sync adding others meanwhile doesn't count.
    mutating func editorGone() -> Bool {
        guard case .closing(let added) = self else { return false }
        self = .idle
        return added
    }
}
