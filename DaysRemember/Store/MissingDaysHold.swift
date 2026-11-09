import Foundation

/// Days iCloud holds that the library came up without at launch: more likely unreadable than deleted
/// on purpose (`CloudLibraryState.missingMost`), so their deletions wait for the user while the rest
/// of the library keeps syncing. The hold ends when the user restores them or confirms their
/// deletion, or once each is back in the library or gone from iCloud; until then it keeps the
/// latest local snapshot, which confirming sends.
struct MissingDaysHold {
    /// The held records' names, whose deletions aren't sent.
    let records: [String]
    /// The latest local snapshot.
    let days: [Day]
    let categories: [CategoryDefinition]

    /// Nil when nothing is missing.
    init?(missing records: [String], days: [Day], categories: [CategoryDefinition]) {
        guard !records.isEmpty else { return nil }
        self.records = records
        self.days = days
        self.categories = categories
    }

    /// How many held records are days, which the notice in 数据与同步 counts.
    var dayCount: Int {
        records.count { $0.hasPrefix("LibraryDay.") }
    }

    /// The hold after a new local snapshot: a record back in the library, or one iCloud no longer
    /// holds (`isHeld` is false), leaves it. Nil once none is left, which lets the snapshot go.
    func updating(days: [Day], categories: [CategoryDefinition],
                  isHeld: (String) -> Bool) -> MissingDaysHold? {
        let names = Set(days.map { CloudLibraryRecord.day($0).recordName }
                        + categories.map { CloudLibraryRecord.category($0).recordName })
        return MissingDaysHold(missing: records.filter { !names.contains($0) && isHeld($0) },
                               days: days, categories: categories)
    }
}
