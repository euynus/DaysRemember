import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    // Stored, UserDefaults-backed (replaces @AppStorage, which @Observable can't
    // observe). Same keys & standard store as before so existing settings carry over.
    /// Synced with the other settings, but finishing onboarding isn't an edit of them: on a new
    /// device it would mark the defaults newer than the account's settings, still downloading.
    var hasOnboarded: Bool { didSet { persist(hasOnboarded, "hasOnboarded") } }
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
    /// Nil until the user has chosen; nothing reaches iCloud before then. Kept out of the synced
    /// snapshot, since one device turning sync off mustn't turn it off on the others.
    var syncChoice: SyncChoice? { didSet { defaults.set(syncChoice?.rawValue, forKey: "sync.choice.v1") } }

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
        syncChoice = d.string(forKey: "sync.choice.v1").flatMap(SyncChoice.init(rawValue:))
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

    /// Stops sending and receiving settings; they keep their local values.
    func disableCloudSync() {
        guard cloudSyncEnabled else { return }
        cloudSyncEnabled = false
        pushTask?.cancel()
        pushTask = nil
        if let cloudChangeToken { cloud.removeChangeHandler(cloudChangeToken) }
        cloudChangeToken = nil
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
        // A device that has finished onboarding never goes back to it.
        hasOnboarded = hasOnboarded || snapshot.hasOnboarded
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
