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
        case accountUnavailable, accountChanged, zoneDeleted, configurationError, failed
    }

    private enum ConfigurationError: LocalizedError {
        case simulator

        var errorDescription: String? {
            String(localized: "当前模拟器构建不启用 iCloud 同步，请在配置开发者团队后的签名真机上验证。本机数据不受影响。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }

    private(set) var status: Status = .idle
    /// What went wrong, kept as a value rather than text so its message follows a language change.
    private enum Problem {
        case accountChanged, zoneDeleted, accountUnavailable
        case cloudKit(CKError)
        case other(Error)
        /// A notice rather than a stop: the rest of the library still syncs.
        case tooLarge(CloudLibraryRecord)
    }

    private var problem: Problem?

    /// Whether the problem, rather than sync activity, decides the status.
    private var problemHoldsStatus: Bool {
        if case .tooLarge = problem { return false }
        return problem != nil
    }

    var errorMessage: String? {
        switch problem {
        case nil:
            return nil
        case .accountChanged:
            return String(localized: "iCloud 账户已退出或变更。本机数据未删除；确认当前账户后才能继续同步。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .zoneDeleted:
            return String(localized: "云端资料区已删除，同步已暂停，未自动重新上传。可以先导出本机备份，再选择重新上传。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .accountUnavailable:
            return String(localized: "请检查系统中的 iCloud 登录、账户限制和网络，再重试同步。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .cloudKit(let error):
            return String(localized: "\(statusMessage)：\(error.localizedDescription)（\(error.errorCode)）", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .other(let error):
            return error.localizedDescription
        case .tooLarge(.day(let day)):
            return String(localized: "「\(day.title)」的文字过长，无法上传到 iCloud；其他日子照常同步。缩短它的笔记后会再上传。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .tooLarge(.category(let category)):
            return String(localized: "分类「\(category.name)」的数据过大，无法上传到 iCloud；其他内容照常同步。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
    }
    private(set) var lastFetchedAt: Date?
    private(set) var lastSentAt: Date?

    var isSyncing: Bool { status == .checkingAccount || status == .syncing }

    var statusMessage: String {
        switch status {
        case .idle: return String(localized: "尚未连接 iCloud", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .checkingAccount: return String(localized: "正在检查 iCloud 账户", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .syncing: return String(localized: "正在与 iCloud 同步", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .pending: return String(localized: "本机更改等待上传", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .synced: return String(localized: "已完成本次 iCloud 同步", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .accountUnavailable: return String(localized: "iCloud 账户暂不可用", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .accountChanged: return String(localized: "iCloud 账户已变更，同步已暂停", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .zoneDeleted: return String(localized: "云端资料区已删除，同步已暂停", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .configurationError: return String(localized: "iCloud 配置未完成", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .failed: return String(localized: "同步未完成，本机数据已保留", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
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
    @ObservationIgnored private var syncAgainAfterThisSync = false
    @ObservationIgnored private var fetching = false
    @ObservationIgnored private var sending = false
    @ObservationIgnored private var startTask: Task<Void, Never>?
    @ObservationIgnored private var inFlightAssets: [ObjectIdentifier: Set<URL>] = [:]

    private var assetDirectory: URL { stateURL.deletingLastPathComponent().appending(path: "Assets", directoryHint: .isDirectory) }

    init(containerIdentifier: String = "iCloud.com.shiguang.daysremember", stateURL: URL? = nil) {
        self.containerIdentifier = containerIdentifier
        self.stateURL = stateURL ?? URL.applicationSupportDirectory
            .appending(path: "CloudLibrarySync", directoryHint: .isDirectory)
            .appending(path: containerIdentifier, directoryHint: .isDirectory)
            .appending(path: "state-v2.json")
        self.photoFiles = PhotoFileStore(directory: self.stateURL.deletingLastPathComponent().appending(path: "Photos", directoryHint: .isDirectory))
        do {
            let legacyURL = self.stateURL.deletingLastPathComponent().appending(path: "state-v1.json")
            let readURL = stateURL == nil && !FileManager.default.fileExists(atPath: self.stateURL.path(percentEncoded: false))
                ? legacyURL : self.stateURL
            state = try CloudLibraryState.read(from: readURL, photoFiles: photoFiles)
            lastFetchedAt = state.lastFetchedAt
            lastSentAt = state.lastSentAt
            if state.accountChangePending { showAccountChange() }
            else if state.zoneWasDeleted { showDeletedZone() }
        } catch {
            storageFailed = true
            status = .failed
            problem = .other(CloudLibraryRecord.RecordError.corruptState)
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
        defer {
            manualSyncRunning = false
            refreshStatus()
            if syncAgainAfterThisSync {
                syncAgainAfterThisSync = false
                Task { [weak self] in await self?.syncNow() }
            }
        }
        problem = nil
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
                  !storageFailed, !problemHoldsStatus else { return }
            canSend = true
            state.hasFetched = true
            state.lastFetchedAt = Date.now
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
            problem = nil
            guard persist() else { return }
            await syncNow()
        } catch { fail(error) }
    }

    /// Only call after the user explicitly asks to upload this library into a new zone, after the
    /// old one was deleted from iCloud.
    func reuploadAfterZoneDeletion() async {
        guard started, !storageFailed, state.zoneWasDeleted, !manualSyncRunning else { return }
        state.forgetServer()
        problem = nil
        guard persist() else { return }
        await syncNow()
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
                problem = .accountUnavailable
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
        guard !problemHoldsStatus else { return }
        if fetching || sending || manualSyncRunning { status = .syncing }
        else if state.hasPendingChanges { status = .pending }
        else if lastFetchedAt != nil && canSend { status = .synced }
        else { status = .idle }
    }

    private func showAccountChange() {
        status = .accountChanged
        problem = .accountChanged
    }

    private func showDeletedZone() {
        status = .zoneDeleted
        problem = .zoneDeleted
    }

    func fail(_ error: Error, stop: Bool = false) {
        if stop { stopEngine() }
        if state.accountChangePending { showAccountChange(); return }
        if error is ConfigurationError {
            status = .configurationError
            problem = .other(error)
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
            problem = .cloudKit(error)
        } else {
            status = .failed
            problem = .other(error)
        }
    }

    /// Names the first record a batch had to leave out, until it fits or is gone.
    func reportTooLarge(_ records: [CloudLibraryRecord]) {
        if let record = records.first {
            problem = .tooLarge(record)
        } else if case .tooLarge(let record) = problem, state.records[record.recordName]?.value != record {
            problem = nil
        }
    }

    /// The engine finished fetching this app's zone.
    func zoneFetchFinished(error: CKError?) {
        if let error {
            if !(error.code == .zoneNotFound && !state.zoneExists && !state.hasFetched) { fail(error) }
            return
        }
        state.hasFetched = true
        state.zoneExists = true
        state.lastFetchedAt = Date.now
        canSend = true
        clearRetriedError()
        guard persist() else { return }
        enqueuePendingChanges()
    }

    /// CloudKit errors from automatic activity are retried by the engine, so an exchange that then
    /// succeeds clears them. Problems that need the user, or a local record, stay.
    private func clearRetriedError() {
        guard case .cloudKit = problem else { return }
        problem = nil
        refreshStatus()
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
            // The whole queue, so changes that can't be sent don't fill the batch's 100 places.
            let changes = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
            let batch = try state.prepareBatch(changes, assetDirectory: assetDirectory)
            reportTooLarge(batch.tooLarge)
            guard persist(), !batch.saves.isEmpty || !batch.deletions.isEmpty else { return nil }
            inFlightAssets[ObjectIdentifier(syncEngine), default: []].formUnion(batch.saves.compactMap { ($0["photo"] as? CKAsset)?.fileURL })
            return CKSyncEngine.RecordZoneChangeBatch(recordsToSave: batch.saves, recordIDsToDelete: batch.deletions, atomicByZone: false)
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
                if let deletion = event.deletions.first(where: { $0.zoneID == CloudLibraryRecord.zoneID }) {
                    // After an encrypted-data reset, iCloud expects the data to be uploaded again.
                    if deletion.reason == .encryptedDataReset {
                        state.forgetServer()
                        _ = persist()
                        stopEngine()
                        if manualSyncRunning { syncAgainAfterThisSync = true }
                        else { Task { [weak self] in await self?.syncNow() } }
                        return
                    }
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
                if !event.savedRecords.isEmpty || !event.deletedRecordIDs.isEmpty { state.lastSentAt = Date.now }
                var failed = false
                for failure in event.failedRecordSaves {
                    if failure.error.code == .serverRecordChanged, let server = failure.error.serverRecord {
                        try state.receive(server, forceServer: true)
                    } else if failure.error.code == .unknownItem {
                        state.receiveDeletion(failure.record.recordID)
                    } else {
                        fail(failure.error)
                        failed = true
                    }
                }
                for (id, error) in event.failedRecordDeletes {
                    if error.code == .unknownItem { state.acknowledgeDeletion(id) }
                    else { fail(error); failed = true }
                }
                if !failed && (!event.savedRecords.isEmpty || !event.deletedRecordIDs.isEmpty) { clearRetriedError() }
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
                if !problemHoldsStatus { status = .syncing }
            case .didFetchRecordZoneChanges(let event):
                guard event.zoneID == CloudLibraryRecord.zoneID else { return }
                zoneFetchFinished(error: event.error)
            case .didFetchChanges:
                fetching = false
                refreshStatus()
            case .willSendChanges:
                sending = true
                if !problemHoldsStatus { status = .syncing }
            case .didSendChanges:
                sending = false
                refreshStatus()
            case .willFetchRecordZoneChanges: break
            @unknown default: break
            }
        } catch { fail(error, stop: true) }
    }
}
