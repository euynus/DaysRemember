import Foundation

struct AppSettingsSnapshot: Codable, Equatable {
    var hasOnboarded: Bool
    var notifPre7: Bool
    var notifPre3: Bool
    var notifPre1: Bool
    var notifDay0: Bool
    var memoryEnabled: Bool
    var momentsEnabled: Bool
    /// Quiet hours were removed: the reminder time is the user's own choice. Still encoded
    /// as `false` so older devices decoding this snapshot deliver at that time too.
    var quietHours = false
    var notificationHour: Int
    var notificationMinute: Int
    var greetingHour = 8
    var greetingMinute = 0

    @MainActor
    init(settings: AppSettings) {
        hasOnboarded = settings.hasOnboarded
        notifPre7 = settings.notifPre7
        notifPre3 = settings.notifPre3
        notifPre1 = settings.notifPre1
        notifDay0 = settings.notifDay0
        memoryEnabled = settings.memoryEnabled
        momentsEnabled = settings.momentsEnabled
        notificationHour = settings.notificationHour
        notificationMinute = settings.notificationMinute
        greetingHour = settings.greetingHour
        greetingMinute = settings.greetingMinute
    }

    /// Snapshots from older devices have no greeting time; they keep the original 08:00.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        hasOnboarded = try values.decode(Bool.self, forKey: .hasOnboarded)
        notifPre7 = try values.decode(Bool.self, forKey: .notifPre7)
        notifPre3 = try values.decode(Bool.self, forKey: .notifPre3)
        notifPre1 = try values.decode(Bool.self, forKey: .notifPre1)
        notifDay0 = try values.decode(Bool.self, forKey: .notifDay0)
        memoryEnabled = try values.decode(Bool.self, forKey: .memoryEnabled)
        momentsEnabled = try values.decode(Bool.self, forKey: .momentsEnabled)
        quietHours = false
        notificationHour = try values.decode(Int.self, forKey: .notificationHour)
        notificationMinute = try values.decode(Int.self, forKey: .notificationMinute)
        greetingHour = try values.decodeIfPresent(Int.self, forKey: .greetingHour) ?? 8
        greetingMinute = try values.decodeIfPresent(Int.self, forKey: .greetingMinute) ?? 0
    }
}
