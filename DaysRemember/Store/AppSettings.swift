import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    // Stored, UserDefaults-backed (replaces @AppStorage, which @Observable can't
    // observe). Same keys & standard store as before so existing settings carry over.
    var hasOnboarded: Bool { didSet { persist(hasOnboarded, "hasOnboarded"); scheduleCloudPush() } }
    var notifPre7: Bool { didSet { persist(notifPre7, "notif.pre7"); scheduleCloudPush() } }
    var notifPre3: Bool { didSet { persist(notifPre3, "notif.pre3"); scheduleCloudPush() } }
    var notifPre1: Bool { didSet { persist(notifPre1, "notif.pre1"); scheduleCloudPush() } }
    var notifDay0: Bool { didSet { persist(notifDay0, "notif.day0"); scheduleCloudPush() } }
    var memoryEnabled: Bool { didSet { persist(memoryEnabled, "notif.memory"); scheduleCloudPush() } }
    var momentsEnabled: Bool { didSet { persist(momentsEnabled, "notif.moments"); scheduleCloudPush() } }
    var notificationHour: Int { didSet { persist(notificationHour, "notif.hour"); scheduleCloudPush() } }
    var notificationMinute: Int { didSet { persist(notificationMinute, "notif.minute"); scheduleCloudPush() } }
    var greetingHour: Int { didSet { persist(greetingHour, "notif.greeting.hour"); scheduleCloudPush() } }
    var greetingMinute: Int { didSet { persist(greetingMinute, "notif.greeting.minute"); scheduleCloudPush() } }

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let cloud = ICloudSyncStore.shared
    @ObservationIgnored private var cloudSyncEnabled = false
    @ObservationIgnored private var cloudChangeToken: UUID?
    @ObservationIgnored private var pushTask: Task<Void, Never>?
    @ObservationIgnored private var isApplyingCloudChange = false
    @ObservationIgnored private var onCloudSettingsApplied: (() -> Void)?

    init() {
        let d = UserDefaults.standard
        hasOnboarded = d.object(forKey: "hasOnboarded") as? Bool ?? false
        notifPre7 = d.object(forKey: "notif.pre7") as? Bool ?? true
        notifPre3 = d.object(forKey: "notif.pre3") as? Bool ?? true
        notifPre1 = d.object(forKey: "notif.pre1") as? Bool ?? false
        notifDay0 = d.object(forKey: "notif.day0") as? Bool ?? true
        memoryEnabled = d.object(forKey: "notif.memory") as? Bool ?? false
        momentsEnabled = d.object(forKey: "notif.moments") as? Bool ?? false
        notificationHour = d.object(forKey: "notif.hour") as? Int ?? 9
        notificationMinute = d.object(forKey: "notif.minute") as? Int ?? 0
        greetingHour = d.object(forKey: "notif.greeting.hour") as? Int ?? 8
        greetingMinute = d.object(forKey: "notif.greeting.minute") as? Int ?? 0
    }

    private func persist(_ value: Bool, _ key: String) { defaults.set(value, forKey: key) }
    private func persist(_ value: Int, _ key: String) { defaults.set(value, forKey: key) }

    func enableCloudSync(onRemoteApply: @escaping () -> Void = {}) {
        onCloudSettingsApplied = onRemoteApply
        guard !cloudSyncEnabled else { return }
        cloudSyncEnabled = true
        cloudChangeToken = cloud.addChangeHandler { [weak self] changedKeys in
            guard changedKeys == nil || changedKeys?.contains(ICloudSyncStore.Key.settings) == true else { return }
            self?.pullSettingsIfNewer()
        }
        reconcileSettingsWithCloud()
    }

    /// Debounced iCloud push, triggered from each setting's didSet (replaces the old
    /// Combine objectWillChange.debounce). Coalesces rapid toggles into one KVS write.
    private func scheduleCloudPush() {
        guard !isApplyingCloudChange else { return }
        let updatedAt = Date.now.timeIntervalSinceReferenceDate
        cloud.noteLocalWrite(for: ICloudSyncStore.Key.settings, updatedAt: updatedAt)
        guard cloudSyncEnabled else { return }
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            self.pushSettingsToCloud(updatedAt: updatedAt)
        }
    }

    private var snapshot: AppSettingsSnapshot {
        AppSettingsSnapshot(settings: self)
    }

    private func reconcileSettingsWithCloud() {
        cloud.reconcile(snapshot, for: ICloudSyncStore.Key.settings, pull: pullSettingsIfNewer)
    }

    @discardableResult
    private func pullSettingsIfNewer() -> Bool {
        guard let remote: ICloudSyncStore.RemoteValue<AppSettingsSnapshot> = cloud.remoteValue(for: ICloudSyncStore.Key.settings) else {
            return false
        }
        return applyRemoteSettingsIfNewer(remote)
    }

    @discardableResult
    func applyRemoteSettingsIfNewer(_ remote: ICloudSyncStore.RemoteValue<AppSettingsSnapshot>) -> Bool {
        guard remote.updatedAt > cloud.localTimestamp(for: ICloudSyncStore.Key.settings) + 0.001 else {
            return false
        }

        pushTask?.cancel()
        pushTask = nil
        isApplyingCloudChange = true
        apply(remote.value)
        cloud.noteLocalWrite(for: ICloudSyncStore.Key.settings, updatedAt: remote.updatedAt)
        isApplyingCloudChange = false
        onCloudSettingsApplied?()
        return true
    }

    private func pushSettingsToCloud(updatedAt: TimeInterval) {
        cloud.push(snapshot, for: ICloudSyncStore.Key.settings, updatedAt: updatedAt)
    }

    private func apply(_ snapshot: AppSettingsSnapshot) {
        hasOnboarded = snapshot.hasOnboarded
        notifPre7 = snapshot.notifPre7
        notifPre3 = snapshot.notifPre3
        notifPre1 = snapshot.notifPre1
        notifDay0 = snapshot.notifDay0
        memoryEnabled = snapshot.memoryEnabled
        momentsEnabled = snapshot.momentsEnabled
        notificationHour = min(23, max(0, snapshot.notificationHour))
        notificationMinute = min(59, max(0, snapshot.notificationMinute))
        greetingHour = min(23, max(0, snapshot.greetingHour))
        greetingMinute = min(59, max(0, snapshot.greetingMinute))
    }
}

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
