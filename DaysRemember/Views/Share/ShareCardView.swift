import Accessibility
import SwiftUI

struct ShareCardView: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let day: Day
    @State private var template: Template = .polaroid
    @State private var ratio: Ratio = .natural
    @State private var includeNote = false
    @State private var sharedImage: SharedImage?
    @State private var savedToast: (id: UUID, text: String, feedback: SensoryFeedback)?

    enum Template: String, CaseIterable {
        case polaroid, note, minimal, collage
        var label: String {
            switch self {
            case .polaroid: return String(localized: "照片", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            case .note: return String(localized: "手记", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            case .minimal: return String(localized: "极简", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            case .collage: return String(localized: "双栏", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            }
        }
    }

    enum Ratio: Hashable {
        /// The card's own height.
        case natural
        /// A 3:4 portrait image, as Xiaohongshu and Moments crop to.
        case portrait
    }

    static let cardWidth: CGFloat = 320
    static let exportPadding: CGFloat = 24
    /// Card aspect that makes the exported image, padding included, exactly 3:4.
    static let portraitCardHeight = (cardWidth + exportPadding * 2) * 4 / 3 - exportPadding * 2
    /// Exports stay sharp on 2x screens and above 1080 px wide everywhere.
    static let minimumExportScale: CGFloat = 3

    private struct SharedImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private var info: DayInfo { DayInfo.compute(day, today: today) }

    private var card: some View {
        let category = store.category(for: day)
        return SharePostcard(day: day, info: info, template: template, includeNote: includeNote,
                             fillsHeight: ratio == .portrait,
                             tint: info.isPast ? Theme.memory : category.tint,
                             ink: info.isPast ? Theme.memoryInk : category.tintInk)
    }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: String(localized: "分享", bundle: AppLocalization.bundle, locale: AppLocalization.locale), onBack: { dismiss() })
            templatePicker
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            HStack(spacing: 14) {
                Text("比例").font(Theme.sans(15)).foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                SegPicker(options: [(Ratio.natural, String(localized: "卡片", bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
                                    (Ratio.portrait, "3:4")], selection: $ratio)
                    .accessibilityIdentifier("share.ratio")
            }
            .cardRow()
            .padding(.horizontal, 6)
            // Days without a note have nothing to include.
            if !day.note.isEmpty {
                ToggleCell(label: String(localized: "包含笔记", bundle: AppLocalization.bundle, locale: AppLocalization.locale), isOn: $includeNote)
                    .accessibilityIdentifier("share.includeNote")
                    .padding(.horizontal, 6)
            }
            ScrollView {
                VStack(spacing: 0) {
                    card
                        .frame(width: Self.cardWidth, height: ratio == .portrait ? Self.portraitCardHeight : nil)
                        .environment(\.dynamicTypeSize, .large)
                        .shadow(color: Theme.ink.opacity(0.10), radius: 18, y: 8)
                }
                .padding(.top, 12)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .safeAreaInset(edge: .bottom) {
            ShareActionBar(onSave: saveToPhotos, onShare: presentShareSheet)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.bg)
        }
        .sensoryFeedback(.selection, trigger: template)
        .sensoryFeedback(trigger: savedToast?.id) { _, _ in savedToast?.feedback }
        .overlay(alignment: .top) {
            if let savedToast {
                Text(savedToast.text)
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.ink.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.top, 60)
                    .transition(.opacity)
            }
        }
        .task(id: savedToast?.id) {
            await hideToastAfterDelay()
        }
        .sheet(item: $sharedImage) { item in
            ShareSheet(activityItems: [item.image])
        }
    }

    // MARK: - Render / share / save (preserved wiring)

    @MainActor
    private func renderCardImage() -> UIImage? {
        Self.renderImage(card: card, ratio: ratio, scale: displayScale)
    }

    @MainActor
    static func renderImage<Card: View>(card: Card, ratio: Ratio, scale: CGFloat) -> UIImage? {
        // Keep the printed card and its on-screen preview at the same text scale.
        let width = cardWidth + exportPadding * 2
        let content = card
            .frame(width: cardWidth, height: ratio == .portrait ? portraitCardHeight : nil)
            .padding(exportPadding)
            .background(Theme.bg)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.locale, AppLocalization.locale)
        let renderer = ImageRenderer(content: content)
        renderer.scale = max(scale, minimumExportScale)
        renderer.proposedSize = .init(width: width, height: ratio == .portrait ? width * 4 / 3 : nil)
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func presentShareSheet() {
        guard let img = renderCardImage() else {
            flashToast(String(localized: "生成失败，请重试", bundle: AppLocalization.bundle, locale: AppLocalization.locale), feedback: .warning)
            return
        }
        sharedImage = SharedImage(image: img)
    }

    private func saveToPhotos() {
        guard let img = renderCardImage() else {
            flashToast(String(localized: "生成失败，请重试", bundle: AppLocalization.bundle, locale: AppLocalization.locale), feedback: .warning)
            return
        }
        Task {
            do {
                try await PhotoSaver.save(image: img)
                flashToast(String(localized: "已保存到相册", bundle: AppLocalization.bundle, locale: AppLocalization.locale), feedback: .success)
            } catch PhotoSaver.SaveError.denied {
                flashToast(String(localized: "无相册权限", bundle: AppLocalization.bundle, locale: AppLocalization.locale), feedback: .warning)
            } catch {
                flashToast(String(localized: "保存失败", bundle: AppLocalization.bundle, locale: AppLocalization.locale), feedback: .warning)
            }
        }
    }

    @MainActor
    private func flashToast(_ text: String, feedback: SensoryFeedback) {
        withAnimation(.easeInOut(duration: 0.18)) { savedToast = (UUID(), text, feedback) }
        AccessibilityNotification.Announcement(text).post()
    }

    @MainActor
    private func hideToastAfterDelay() async {
        guard let toastID = savedToast?.id else { return }
        do { try await Task.sleep(for: .milliseconds(1700)) }
        catch { return }
        guard !Task.isCancelled, savedToast?.id == toastID else { return }
        withAnimation(.easeInOut(duration: 0.25)) { savedToast = nil }
    }

    // MARK: - Template chips

    private var templatePicker: some View {
        Picker("分享模板", selection: $template) {
            ForEach(Template.allCases, id: \.self) { item in
                Text(item.label).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }
}
