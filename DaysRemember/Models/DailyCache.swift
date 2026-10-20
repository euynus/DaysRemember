import Foundation
import Synchronization

/// Memoized results that change only with the day. Each key carries the day it was computed
/// for; entries for an earlier day are never hit again, so the first result stored for a new day
/// drops them, and a cap bounds unusual mixes.
final class DailyCache<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    private let state = Mutex<(day: TimeInterval?, entries: [Key: Value])>((nil, [:]))

    /// The stored result for `key`, or `compute`'s, stored for `day`.
    func value(for key: Key, on day: TimeInterval, compute: () -> Value) -> Value {
        if let hit = state.withLock({ $0.entries[key] }) { return hit }
        let value = compute()
        state.withLock { state in
            if day != state.day || state.entries.count >= 4096 {
                state.entries.removeAll(keepingCapacity: true)
                state.day = day
            }
            state.entries[key] = value
        }
        return value
    }
}
