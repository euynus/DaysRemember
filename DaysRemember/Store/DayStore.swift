import Foundation
import SwiftUI

@MainActor
final class DayStore: ObservableObject {
    @Published var days: [Day] {
        didSet {
            save()
            rescheduleNotifications()
        }
    }

    private let storageKey = "days.v1"
    /// Set after init so we can wire the notification scheduler without a circular dependency.
    var settings: AppSettings? {
        didSet { rescheduleNotifications() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Day].self, from: data) {
            self.days = decoded
        } else {
            self.days = SampleData.days
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(days) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func add(_ day: Day) { days.insert(day, at: 0) }
    func update(_ day: Day) {
        if let i = days.firstIndex(where: { $0.id == day.id }) { days[i] = day }
    }
    func delete(_ day: Day) {
        let id = day.id
        days.removeAll { $0.id == id }
        Task { await NotificationManager.shared.cancel(dayId: id) }
    }

    /// Nearest upcoming (future or today) within `within` days.
    func nearestUpcoming(within: Int = 100) -> Day? {
        days
            .map { ($0, DayInfo.compute($0)) }
            .filter { !$0.1.isPast && $0.1.days <= within }
            .sorted { $0.1.days < $1.1.days }
            .first?.0
    }

    func resetToSamples() { days = SampleData.days }

    func rescheduleNotifications() {
        guard let settings else { return }
        let snapshot = days
        Task { await NotificationManager.shared.sync(days: snapshot, settings: settings) }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false
    @AppStorage("notif.pre7") var notifPre7: Bool = true
    @AppStorage("notif.pre3") var notifPre3: Bool = true
    @AppStorage("notif.pre1") var notifPre1: Bool = false
    @AppStorage("notif.day0") var notifDay0: Bool = true
    @AppStorage("notif.memory") var memoryEnabled: Bool = true
    @AppStorage("notif.moments") var momentsEnabled: Bool = true
    @AppStorage("notif.quiet") var quietHours: Bool = true
}
