import CloudKit
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class CloudLibrarySync: CKSyncEngineDelegate {
    static let shared = CloudLibrarySync()

    enum Status: String {
        case idle, checkingAccount, syncing, pending, synced
        case accountUnavailable, accountChanged, configurationError, failed
    }

    private enum ConfigurationError: LocalizedError {
        case simulator

        var errorDescription: String? {
            "当前模拟器构建不启用 iCloud 同步，请在配置开发者团队后的签名真机上验证。本机数据不受影响。"
        }
    }

    private(set) var status: Status = .idle
    private(set) var errorMessage: String?
    private(set) var lastFetchedAt: Date?
    private(set) var lastSentAt: Date?

    var isSyncing: Bool { status == .checkingAccount || status == .syncing }

    var statusMessage: String {
        switch status {
        case .idle: return "尚未连接 iCloud"
        case .checkingAccount: return "正在检查 iCloud 账户"
        case .syncing: return "正在与 iCloud 同步"
        case .pending: return "本机更改等待上传"
        case .synced: return "已完成本次 iCloud 同步"
        case .accountUnavailable: return "iCloud 账户暂不可用"
        case .accountChanged: return "iCloud 账户已变更，同步已暂停"
        case .configurationError: return "iCloud 配置未完成"
        case .failed: return "同步未完成，本机数据已保留"
        }
    }

    @ObservationIgnored private let containerIdentifier: String
    @ObservationIgnored private let stateURL: URL
    @ObservationIgnored private let photoFiles: PhotoFileStore
    @ObservationIgnored private var state = CloudLibraryState()
    @ObservationIgnored private var container: CKContainer?
    @ObservationIgnored private var engine: CKSyncEngine?
    @ObservationIgnored private var onRemoteChange: ((CloudLibraryUpdate) throws -> Void)?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var storageFailed = false
    @ObservationIgnored private var localSnapshotKnown = false
    @ObservationIgnored private var canSend = false
    @ObservationIgnored private var manualSyncRunning = false
    @ObservationIgnored private var fetching = false
    @ObservationIgnored private var sending = false
    @ObservationIgnored private var startTask: Task<Void, Never>?
    @ObservationIgnored private var inFlightAssets: [ObjectIdentifier: Set<URL>] = [:]

    private var assetDirectory: URL { stateURL.deletingLastPathComponent().appendingPathComponent("Assets") }

    init(containerIdentifier: String = "iCloud.com.shiguang.daysremember", stateURL: URL? = nil) {
        self.containerIdentifier = containerIdentifier
        self.stateURL = stateURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CloudLibrarySync", isDirectory: true)
            .appendingPathComponent(containerIdentifier, isDirectory: true)
            .appendingPathComponent("state-v2.json")
        self.photoFiles = PhotoFileStore(directory: self.stateURL.deletingLastPathComponent().appendingPathComponent("Photos"))
        do {
            let legacyURL = self.stateURL.deletingLastPathComponent().appendingPathComponent("state-v1.json")
            let readURL = stateURL == nil && !FileManager.default.fileExists(atPath: self.stateURL.path)
                ? legacyURL : self.stateURL
            state = try CloudLibraryState.read(from: readURL, photoFiles: photoFiles)
            lastFetchedAt = state.lastFetchedAt
            lastSentAt = state.lastSentAt
            if state.accountChangePending { showAccountChange() }
            else if state.zoneWasDeleted { showDeletedZone() }
        } catch {
            storageFailed = true
            status = .failed
            errorMessage = CloudLibraryRecord.RecordError.corruptState.localizedDescription
        }
    }

    /// Throw if recovery values or remote changes cannot be durably saved by ID.
    func start(days: [Day], categories: [CategoryDefinition],
               onRemoteChange: @escaping (CloudLibraryUpdate) throws -> Void) {
        self.onRemoteChange = onRemoteChange
        guard !storageFailed else { return }
        let wasStarted = started
        started = true
        var days = days
        var categories = categories
        if !state.pendingRemoteUpdate.isEmpty {
            let update = state.pendingRemoteUpdate
            let replacedDays = Set(update.deletedDayIDs + update.upsertedDays.map(\.id))
            let replacedCategories = Set(update.deletedCategoryIDs + update.upsertedCategories.map(\.id))
            days = days.filter { !replacedDays.contains($0.id) } + update.upsertedDays
            categories = categories.filter { !replacedCategories.contains($0.id) } + update.upsertedCategories
            guard deliverRemoteUpdate() else { return }
        }
        updateLocal(days: days, categories: categories)
        guard !wasStarted else { return }
        startTask = Task { [weak self] in await self?.syncNow() }
    }

    func updateLocal(days: [Day], categories: [CategoryDefinition]) {
        guard !storageFailed else { return }
        do {
            try state.updateLocal(days: days, categories: categories,
                                  inferDeletions: localSnapshotKnown || state.hasFetched)
            localSnapshotKnown = true
            guard persist() else { return }
            enqueuePendingChanges()
            refreshStatus()
        } catch { fail(error, stop: true) }
    }

    func syncNow() async {
        guard started, !storageFailed, !manualSyncRunning else { return }
        guard !state.accountChangePending else { showAccountChange(); return }
        guard !state.zoneWasDeleted else { showDeletedZone(); return }
        manualSyncRunning = true
        defer { manualSyncRunning = false; refreshStatus() }
        errorMessage = nil
        status = .checkingAccount
        do {
            guard deliverRemoteUpdate() else { return }
            let container = try cloudContainer()
            guard let account = try await availableAccount(in: container) else { return }
            guard state.acceptAccount(account) else {
                _ = persist()
                stopEngine()
                showAccountChange()
                return
            }
            guard persist() else { return }
            let engine = self.engine ?? makeEngine(in: container)
            status = .syncing
            do {
                try await engine.fetchChanges(.init(scope: .zoneIDs([CloudLibraryRecord.zoneID])))
            } catch let error as CKError where error.code == .zoneNotFound && !state.zoneExists && !state.hasFetched {
                // First use of this account: no records can be overwritten in an absent zone.
            }
            guard self.engine === engine, !state.accountChangePending, !state.zoneWasDeleted,
                  !storageFailed, errorMessage == nil else { return }
            canSend = true
            state.hasFetched = true
            state.lastFetchedAt = Date()
            guard persist() else { return }
            enqueuePendingChanges()
            try await engine.sendChanges(.init(scope: .zoneIDs([CloudLibraryRecord.zoneID])))
        } catch { fail(error) }
    }

    /// Only call after a user explicitly approves uploading this local library to the current account.
    func confirmAccountChangeAndSync() async {
        guard started, !storageFailed, state.accountChangePending, !manualSyncRunning else { return }
        do {
            guard let account = try await availableAccount(in: cloudContainer()) else { return }
            let previous = engine
            stopEngine()
            await previous?.cancelOperations()
            _ = state.acceptAccount(account, confirmed: true)
            errorMessage = nil
            guard persist() else { return }
            await syncNow()
        } catch { fail(error) }
    }

    private func cloudContainer() throws -> CKContainer {
        #if targetEnvironment(simulator)
        throw ConfigurationError.simulator
        #else
        if let container { return container }
        let container = CKContainer(identifier: containerIdentifier)
        self.container = container
        return container
        #endif
    }

    private func availableAccount(in container: CKContainer) async throws -> String? {
        let accountStatus = try await container.accountStatus()
        guard accountStatus == .available else {
            if state.accountRecordName != nil && accountStatus == .noAccount {
                state.accountChangePending = true
                _ = persist()
                stopEngine()
                showAccountChange()
            } else {
                status = .accountUnavailable
                errorMessage = "请检查系统中的 iCloud 登录、账户限制和网络，再重试同步。"
            }
            return nil
        }
        return try await container.userRecordID().recordName
    }

    private func makeEngine(in container: CKContainer) -> CKSyncEngine {
        var configuration = CKSyncEngine.Configuration(database: container.privateCloudDatabase,
                                                       stateSerialization: state.engineState, delegate: self)
        configuration.automaticallySync = true
        let engine = CKSyncEngine(configuration)
        self.engine = engine
        canSend = false
        return engine
    }

    private func stopEngine() {
        let previous = engine
        engine = nil
        canSend = false
        fetching = false
        sending = false
        if let previous {
            Task { [weak self] in
                await previous.cancelOperations()
                self?.inFlightAssets[ObjectIdentifier(previous)] = nil
                self?.cleanAssets()
            }
        }
    }

    private func enqueuePendingChanges() {
        guard let engine, canSend, !storageFailed, !state.accountChangePending, !state.zoneWasDeleted else { return }
        if !state.zoneExists {
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: CloudLibraryRecord.zoneID))])
        }
        let pending: [CKSyncEngine.PendingRecordZoneChange] = state.records.compactMap { name, entry in
            guard entry.dirty else { return nil }
            let id = CKRecord.ID(recordName: name, zoneID: CloudLibraryRecord.zoneID)
            return entry.value == nil ? .deleteRecord(id) : .saveRecord(id)
        }
        let expected = Set(pending)
        engine.state.remove(pendingRecordZoneChanges: engine.state.pendingRecordZoneChanges.filter { !expected.contains($0) })
        engine.state.add(pendingRecordZoneChanges: pending)
    }

    private func persist() -> Bool {
        guard !storageFailed else { return false }
        do {
            try state.write(to: stateURL, photoFiles: photoFiles)
            lastFetchedAt = state.lastFetchedAt
            lastSentAt = state.lastSentAt
            return true
        } catch {
            storageFailed = true
            fail(error, stop: true)
            return false
        }
    }

    @discardableResult
    private func deliverRemoteUpdate() -> Bool {
        guard !state.pendingRemoteUpdate.isEmpty else { return true }
        guard let onRemoteChange else { return false }
        do {
            try onRemoteChange(state.pendingRemoteUpdate)
        } catch {
            _ = persist()
            fail(error, stop: true)
            return false
        }
        state.acknowledgeRemoteUpdate()
        return persist()
    }

    private func refreshStatus() {
        if state.accountChangePending { showAccountChange(); return }
        if state.zoneWasDeleted { showDeletedZone(); return }
        guard errorMessage == nil else { return }
        if fetching || sending || manualSyncRunning { status = .syncing }
        else if state.hasPendingChanges { status = .pending }
        else if lastFetchedAt != nil && canSend { status = .synced }
        else { status = .idle }
    }

    private func showAccountChange() {
        status = .accountChanged
        errorMessage = "iCloud 账户已退出或变更。本机数据未删除；确认当前账户后才能继续同步。"
    }

    private func showDeletedZone() {
        status = .failed
        errorMessage = "云端资料区已删除，同步已暂停，未自动重新上传。请先导出本机备份。"
    }

    private func fail(_ error: Error, stop: Bool = false) {
        if stop { stopEngine() }
        if state.accountChangePending { showAccountChange(); return }
        if error is ConfigurationError {
            status = .configurationError
            errorMessage = error.localizedDescription
            stopEngine()
        } else if let error = error as? CKError {
            switch error.code {
            case .notAuthenticated:
                status = .accountUnavailable
            case .missingEntitlement, .badContainer, .badDatabase, .permissionFailure, .invalidArguments, .serverRejectedRequest:
                status = .configurationError
                stopEngine()
            default: status = .failed
            }
            errorMessage = "\(statusMessage)：\(error.localizedDescription)（\(error.errorCode)）"
        } else {
            status = .failed
            errorMessage = error.localizedDescription
        }
    }

    func nextFetchChangesOptions(_ context: CKSyncEngine.FetchChangesContext,
                                 syncEngine: CKSyncEngine) async -> CKSyncEngine.FetchChangesOptions {
        .init(scope: .zoneIDs([CloudLibraryRecord.zoneID]))
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                   syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard engine === syncEngine, canSend, !storageFailed,
              !state.accountChangePending, !state.zoneWasDeleted else { return nil }
        do {
            // Recheck ownership before handing any private payloads to the engine.
            guard let account = try await availableAccount(in: cloudContainer()), engine === syncEngine else { return nil }
            guard state.acceptAccount(account) else {
                _ = persist()
                stopEngine()
                showAccountChange()
                return nil
            }
            var saves: [CKRecord] = []
            var deletions: [CKRecord.ID] = []
            let changes = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }.prefix(100)
            for change in changes {
                switch change {
                case .saveRecord(let id):
                    guard var entry = state.records[id.recordName], entry.dirty, let value = entry.value else { continue }
                    let record = try value.makeRecord(systemFields: entry.systemFields, revision: entry.revision,
                                                      assetDirectory: assetDirectory)
                    entry.sentRevision = entry.revision
                    entry.sentFingerprint = try value.fingerprint()
                    state.records[id.recordName] = entry
                    saves.append(record)
                case .deleteRecord(let id):
                    guard var entry = state.records[id.recordName], entry.dirty, entry.value == nil else { continue }
                    entry.sentRevision = entry.revision
                    entry.sentFingerprint = nil
                    state.records[id.recordName] = entry
                    deletions.append(id)
                @unknown default: break
                }
            }
            guard persist(), !saves.isEmpty || !deletions.isEmpty else { return nil }
            inFlightAssets[ObjectIdentifier(syncEngine), default: []].formUnion(saves.compactMap { ($0["photo"] as? CKAsset)?.fileURL })
            return CKSyncEngine.RecordZoneChangeBatch(recordsToSave: saves, recordIDsToDelete: deletions, atomicByZone: false)
        } catch {
            fail(error, stop: !(error is CKError))
            return nil
        }
    }

    private func cleanAssets() {
        guard !storageFailed else { return }
        var referenced = Set(inFlightAssets.values.flatMap { $0 })
        for (name, entry) in state.records where entry.dirty && entry.value != nil {
            referenced.insert(CloudLibraryRecord.assetURL(recordName: name, revision: entry.revision, directory: assetDirectory))
        }
        do { try CloudLibraryRecord.removeUnusedAssets(in: assetDirectory, keeping: referenced) }
        catch { Logger(subsystem: "com.shiguang.daysremember", category: "CloudLibrarySync").error("Asset cleanup failed: \(error.localizedDescription)") }
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard engine === syncEngine, !storageFailed else { return }
        do {
            switch event {
            case .stateUpdate(let event):
                state.engineState = event.stateSerialization
                _ = persist()
            case .accountChange(let event):
                switch event.changeType {
                case .signIn(let user):
                    if state.acceptAccount(user.recordName) { _ = persist(); return }
                case .signOut, .switchAccounts:
                    state.accountChangePending = true
                @unknown default:
                    state.accountChangePending = true
                }
                _ = persist()
                stopEngine()
                showAccountChange()
            case .fetchedDatabaseChanges(let event):
                if event.deletions.contains(where: { $0.zoneID == CloudLibraryRecord.zoneID }) {
                    state.zoneWasDeleted = true
                    _ = persist()
                    stopEngine()
                    showDeletedZone()
                    return
                }
                if event.modifications.contains(where: { $0.zoneID == CloudLibraryRecord.zoneID }) { state.zoneExists = true }
                _ = persist()
            case .fetchedRecordZoneChanges(let event):
                var candidate = state
                for modification in event.modifications where modification.record.recordID.zoneID == CloudLibraryRecord.zoneID {
                    try candidate.receive(modification.record)
                }
                for deletion in event.deletions { candidate.receiveDeletion(deletion.recordID) }
                state = candidate
                guard persist() else { return }
                guard deliverRemoteUpdate() else { return }
                enqueuePendingChanges()
            case .sentRecordZoneChanges(let event):
                // A sent event completes this batch, including its failed records. Other engines may still be cancelling.
                for record in event.savedRecords + event.failedRecordSaves.map(\.record) {
                    if let revision = record["revision"] as? String {
                        let url = CloudLibraryRecord.assetURL(recordName: record.recordID.recordName, revision: revision, directory: assetDirectory)
                        inFlightAssets[ObjectIdentifier(syncEngine)]?.remove(url)
                    }
                }
                for record in event.savedRecords { try state.acknowledgeSave(record) }
                for id in event.deletedRecordIDs { state.acknowledgeDeletion(id) }
                if !event.savedRecords.isEmpty || !event.deletedRecordIDs.isEmpty { state.lastSentAt = Date() }
                for failure in event.failedRecordSaves {
                    if failure.error.code == .serverRecordChanged, let server = failure.error.serverRecord {
                        try state.receive(server, forceServer: true)
                    } else if failure.error.code == .unknownItem {
                        state.receiveDeletion(failure.record.recordID)
                    } else {
                        fail(failure.error)
                    }
                }
                for (id, error) in event.failedRecordDeletes {
                    if error.code == .unknownItem { state.acknowledgeDeletion(id) }
                    else { fail(error) }
                }
                guard persist() else { return }
                cleanAssets()
                guard deliverRemoteUpdate() else { return }
                enqueuePendingChanges()
            case .sentDatabaseChanges(let event):
                if event.savedZones.contains(where: { $0.zoneID == CloudLibraryRecord.zoneID }) { state.zoneExists = true }
                for failure in event.failedZoneSaves { fail(failure.error) }
                for error in event.failedZoneDeletes.values { fail(error) }
                _ = persist()
            case .willFetchChanges:
                fetching = true
                if errorMessage == nil { status = .syncing }
            case .didFetchRecordZoneChanges(let event):
                guard event.zoneID == CloudLibraryRecord.zoneID else { return }
                if let error = event.error {
                    if !(error.code == .zoneNotFound && !state.zoneExists && !state.hasFetched) { fail(error) }
                } else {
                    state.hasFetched = true
                    state.zoneExists = true
                    state.lastFetchedAt = Date()
                    canSend = true
                    guard persist() else { return }
                    enqueuePendingChanges()
                }
            case .didFetchChanges:
                fetching = false
                refreshStatus()
            case .willSendChanges:
                sending = true
                if errorMessage == nil { status = .syncing }
            case .didSendChanges:
                sending = false
                refreshStatus()
            case .willFetchRecordZoneChanges: break
            @unknown default: break
            }
        } catch { fail(error, stop: true) }
    }
}
