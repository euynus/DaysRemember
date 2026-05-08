import Foundation

@MainActor
final class ICloudSyncStore {
    static let shared = ICloudSyncStore()

    enum Key {
        static let days = "icloud.days.v1"
        static let categories = "icloud.categories.v1"
        static let settings = "icloud.settings.v1"
    }

    struct RemoteValue<Value> {
        var value: Value
        var updatedAt: TimeInterval
        var deviceID: String
    }

    private struct Envelope<Value: Codable>: Codable {
        var updatedAt: TimeInterval
        var deviceID: String
        var value: Value
    }

    private let store = NSUbiquitousKeyValueStore.default
    private let defaults = SharedStorage.defaults
    private let maxEnvelopeBytes = 950_000
    private var observer: NSObjectProtocol?
    private var handlers: [UUID: (Set<String>?) -> Void] = [:]

    private init() {}

    var deviceID: String {
        let key = "icloud.deviceID"
        if let existing = defaults.string(forKey: key) {
            return existing
        }
        let created = UUID().uuidString
        defaults.set(created, forKey: key)
        return created
    }

    @discardableResult
    func addChangeHandler(_ handler: @escaping (Set<String>?) -> Void) -> UUID {
        startObserving()
        let token = UUID()
        handlers[token] = handler
        store.synchronize()
        return token
    }

    func localTimestamp(for key: String) -> TimeInterval {
        defaults.double(forKey: localTimestampKey(for: key))
    }

    func noteLocalWrite(for key: String, updatedAt: TimeInterval) {
        defaults.set(updatedAt, forKey: localTimestampKey(for: key))
    }

    @discardableResult
    func push<Value: Codable>(_ value: Value, for key: String,
                              updatedAt: TimeInterval = Date().timeIntervalSinceReferenceDate) -> Bool {
        noteLocalWrite(for: key, updatedAt: updatedAt)

        let envelope = Envelope(updatedAt: updatedAt, deviceID: deviceID, value: value)
        guard let data = try? JSONEncoder().encode(envelope),
              data.count <= maxEnvelopeBytes else {
            return false
        }

        store.set(data, forKey: key)
        store.synchronize()
        return true
    }

    func remoteValue<Value: Codable>(for key: String, as type: Value.Type = Value.self) -> RemoteValue<Value>? {
        guard let data = store.data(forKey: key),
              let envelope = try? JSONDecoder().decode(Envelope<Value>.self, from: data) else {
            return nil
        }
        return RemoteValue(value: envelope.value, updatedAt: envelope.updatedAt, deviceID: envelope.deviceID)
    }

    private func startObserving() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            let keys = Self.changedKeys(from: notification)
            Task { @MainActor [weak self] in
                self?.notifyHandlers(changedKeys: keys)
            }
        }
    }

    private func notifyHandlers(changedKeys: Set<String>?) {
        for handler in handlers.values {
            handler(changedKeys)
        }
    }

    private func localTimestampKey(for key: String) -> String {
        "icloud.localTimestamp.\(key)"
    }

    private nonisolated static func changedKeys(from notification: Notification) -> Set<String>? {
        guard let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
              !keys.isEmpty else {
            return nil
        }
        return Set(keys)
    }
}
