import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(DayStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var cloud = CloudLibrarySync.shared
    @State private var exporting = false
    @State private var importing = false
    @State private var isReading = false
    @State private var document = BackupDocument(data: Data())
    @State private var filename = String(localized: "时光备份", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    @State private var pendingImport: DayBackup?
    @State private var confirmRecovery = false
    @State private var confirmRawCopyDeletion = false
    @State private var confirmLegacyImport = false
    @State private var hasLegacyData = false
    @State private var confirmAccountChange = false
    @State private var confirmReupload = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            dataForm
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("数据与同步")
            .navigationBarTitleDisplayMode(.inline)
            // Only devices that used the pre-CloudKit builds have legacy records, which may
            // still be downloading when this opens.
            .onAppear { hasLegacyData = store.hasUnseenLegacyCloudData() }
            .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
                .receive(on: RunLoop.main)) { _ in
                hasLegacyData = store.hasUnseenLegacyCloudData()
            }
            .toolbar {
                if store.loadError == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("关闭", systemImage: "xmark") { dismiss() }
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json,
                          defaultFilename: filename) { result in
                switch result {
                case .success: message = String(localized: "备份已导出。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                case .failure(let error): message = error.localizedDescription
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                readBackup(result)
            }
            .alert("数据与同步", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) {
                Button("好", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
        .tint(Theme.accent)
    }

    private var dataForm: some View {
        Form {
            if let error = store.loadError ?? store.saveError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.accent)
                    Button("导出原始数据", systemImage: "square.and.arrow.up") {
                        prepareExport(name: String(localized: "时光原始数据", bundle: AppLocalization.bundle, locale: AppLocalization.locale), data: { try store.exportOriginalData() })
                    }
                }
            }
            Section("iCloud") {
                Label(cloud.statusMessage, systemImage: "icloud")
                if let error = store.syncPreparationError {
                    Text(error).foregroundStyle(Theme.accent)
                }
                if let error = cloud.errorMessage {
                    Text(error).foregroundStyle(Theme.accent)
                }
                if let date = cloud.lastSentAt {
                    LabeledContent("最近发送") { Text(date, format: .dateTime.month().day().hour().minute()) }
                }
                if let date = cloud.lastFetchedAt {
                    LabeledContent("最近接收") { Text(date, format: .dateTime.month().day().hour().minute()) }
                }
                Button {
                    store.enableCloudSync()
                    Task { await cloud.syncNow() }
                } label: {
                    Label("同步", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(cloud.isSyncing || store.loadError != nil)
                NavigationLink {
                    SyncConflictsView()
                } label: {
                    Label("同步保留版本（\(store.syncConflicts.count)）", systemImage: "clock.arrow.circlepath")
                }
                .disabled(store.loadError != nil)
                if cloud.status == .accountChanged {
                    Button("确认使用当前 iCloud 账户", systemImage: "person.crop.circle.badge.checkmark") {
                        confirmAccountChange = true
                    }
                    .confirmationDialog("将本机日子同步到当前账户？", isPresented: $confirmAccountChange, titleVisibility: .visible) {
                        Button("确认并同步") { Task { await cloud.confirmAccountChangeAndSync() } }
                        Button("取消", role: .cancel) {}
                    } message: {
                        Text("本机日子及照片将上传到系统当前登录的 iCloud 账户，请先确认账户归属。")
                    }
                }
                if cloud.status == .zoneDeleted {
                    Button("重新上传到 iCloud", systemImage: "icloud.and.arrow.up") {
                        confirmReupload = true
                    }
                    .confirmationDialog("重新上传本机日子？", isPresented: $confirmReupload, titleVisibility: .visible) {
                        Button("重新上传") { Task { await cloud.reuploadAfterZoneDeletion() } }
                        Button("取消", role: .cancel) {}
                    } message: {
                        Text("iCloud 中时光的资料已被删除。本机日子及照片会重新上传，并同步到你的其他设备。")
                    }
                }
                if hasLegacyData {
                    Button("导入旧版 iCloud 数据", systemImage: "icloud.and.arrow.down") {
                        confirmLegacyImport = true
                    }
                    .disabled(store.loadError != nil)
                    .confirmationDialog("导入旧版 iCloud 数据？", isPresented: $confirmLegacyImport, titleVisibility: .visible) {
                        Button("追加导入") {
                            do {
                                let count = try store.importLegacyCloudData()
                                message = count > 0 ? String(localized: "已导入 \(count) 个日子。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                                    : String(localized: "未发现可导入的新日子。旧数据可能仍在下载，请稍后重试。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                            } catch { message = error.localizedDescription }
                            hasLegacyData = store.hasUnseenLegacyCloudData()
                        }
                        Button("取消", role: .cancel) {}
                    } message: {
                        Text("仅追加本机未见过的记录，不覆盖已有记录。旧版数据可能包含曾在其他设备删除的日子；所有设备请升级后再编辑。")
                    }
                }
            }
            backupSection
            Section {
                NavigationLink {
                    RecentlyDeletedView()
                } label: {
                    Label("最近删除（\(store.deletedDays.count)）", systemImage: "trash")
                }
                .disabled(store.loadError != nil)
            } footer: {
                Text("最近删除和同步保留版本保留 30 天。它们与本机恢复副本都只保存在这台设备。")
            }
        }
    }

    private var backupSection: some View {
        Section {
            Button("导出备份", systemImage: "square.and.arrow.up") {
                prepareExport(name: String(localized: "时光备份", bundle: AppLocalization.bundle, locale: AppLocalization.locale), data: store.exportBackup)
            }
            .disabled(store.loadError != nil)
            Button("从文件恢复", systemImage: "square.and.arrow.down") { importing = true }
                .disabled(isReading)
                .confirmationDialog("恢复此备份？", isPresented: Binding(
                    get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }
                ), titleVisibility: .visible) {
                    Button("恢复备份", role: .destructive) {
                        guard let backup = pendingImport else { return }
                        perform { try store.restoreBackup(backup) }
                        pendingImport = nil
                    }
                    Button("取消", role: .cancel) { pendingImport = nil }
                } message: {
                    Text("当前 \(store.days.count) 个日子将被备份中的 \(pendingImport?.days.count ?? 0) 个日子替换，并同步到其他设备。替换前会保留本机副本。")
                }
            if isReading { ProgressView("正在读取备份") }
            if store.hasRecoveryBackup {
                Button("恢复上一次本机副本", systemImage: "arrow.uturn.backward") {
                    confirmRecovery = true
                }
                .confirmationDialog("恢复上一次本机副本？", isPresented: $confirmRecovery, titleVisibility: .visible) {
                    Button("恢复", role: .destructive) { perform { try store.restorePreviousBackup() } }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("将替换当前日子和分类，并同步到其他设备。当前数据会留为新的本机副本。")
                }
            }
            // A library replaced while it couldn't be read is kept as raw data.
            if store.loadError == nil && store.hasUnreadableDataCopy {
                Button("导出替换前的原始数据", systemImage: "doc.badge.clock") {
                    prepareExport(name: String(localized: "时光替换前的原始数据", bundle: AppLocalization.bundle, locale: AppLocalization.locale), data: store.exportUnreadableDataCopy)
                }
                Button("删除替换前的原始数据", systemImage: "trash", role: .destructive) {
                    confirmRawCopyDeletion = true
                }
                .confirmationDialog("删除替换前的原始数据？", isPresented: $confirmRawCopyDeletion, titleVisibility: .visible) {
                    Button("删除", role: .destructive) { store.deleteUnreadableDataCopy() }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("这份数据包含恢复备份时被替换的日子和照片，删除后无法找回。")
                }
            }
            if store.hasMigrationBackup {
                Button("导出迁移前备份", systemImage: "externaldrive") {
                    prepareExport(name: String(localized: "时光迁移前备份", bundle: AppLocalization.bundle, locale: AppLocalization.locale), data: store.exportMigrationBackup)
                }
            }
        } header: {
            Text("备份与恢复")
        } footer: {
            Text("备份包含日子、照片、分类、最近删除和同步保留版本。文件未加密，请保存在可信的位置。恢复不会改变系统通知权限。")
        }
    }

    /// Dated on the app's calendar; the ISO 8601 style alone would use UTC.
    static func filename(_ name: String, on date: Date) -> String {
        let day = Date.ISO8601FormatStyle(timeZone: CNDate.calendar.timeZone).year().month().day().dateSeparator(.dash)
        return name + "-" + date.formatted(day)
    }

    private func prepareExport(name: String, data: () throws -> Data) {
        do {
            document = BackupDocument(data: try data())
            filename = Self.filename(name, on: .now)
            exporting = true
        } catch { message = error.localizedDescription }
    }

    private func readBackup(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error): message = error.localizedDescription
        case .success(let url):
            isReading = true
            Task {
                defer { isReading = false }
                do {
                    pendingImport = try await DayBackup.load(from: url)
                } catch { message = error.localizedDescription }
            }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            message = String(localized: "数据已恢复。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        } catch { message = error.localizedDescription }
    }
}
