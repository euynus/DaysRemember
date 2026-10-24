import Foundation

struct AppSettingsSnapshot: Codable, Equatable {
    var hasOnboarded: Bool
    var notifPre7: Bool
    var notifPre3: Bool
    var notifPre1: Bool
    var notifDay0: Bool
    var memoryEnabled: Bool
    var momentsEnabled: Bool
    var notificationHour: Int
    var notificationMinute: Int
    var greetingHour: Int
    var greetingMinute: Int

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
}
