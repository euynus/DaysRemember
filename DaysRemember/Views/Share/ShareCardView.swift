import Accessibility
import SwiftUI

struct ShareCardView: View {
    @Environment(\.currentDay) private var today
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: Day
    @State private var template: Template = .polaroid
    @State private var ratio: Ratio = .natural
    @State private var includeNote = false
    @State private var sharedImage: SharedImage?
    @State private var savedToast: (id: UUID, text: String)?

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
        SharePostcard(day: day, info: info, template: template, includeNote: includeNote,
                      fillsHeight: ratio == .portrait)
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
                        .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 5)
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
            shareGrid
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Theme.bg)
        }
        .sensoryFeedback(.selection, trigger: template)
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
            Haptics.warning()
            flashToast(String(localized: "生成失败，请重试", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            return
        }
        sharedImage = SharedImage(image: img)
    }

    private func saveToPhotos() {
        guard let img = renderCardImage() else {
            Haptics.warning()
            flashToast(String(localized: "生成失败，请重试", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            return
        }
        Task {
            do {
                try await PhotoSaver.save(image: img)
                Haptics.success()
                flashToast(String(localized: "已保存到相册", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            } catch PhotoSaver.SaveError.denied {
                Haptics.warning()
                flashToast(String(localized: "无相册权限", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            } catch {
                Haptics.warning()
                flashToast(String(localized: "保存失败", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            }
        }
    }

    @MainActor
    private func flashToast(_ text: String) {
        withAnimation(.easeInOut(duration: 0.18)) { savedToast = (UUID(), text) }
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

    private var shareGrid: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            Button(action: presentShareSheet) {
                Label("分享图片", systemImage: "square.and.arrow.up")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            Button(action: saveToPhotos) {
                Label("保存", systemImage: "square.and.arrow.down")
                    .lineLimit(1)
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
        }
    }
}

struct SharePostcard: View {
    let day: Day
    let info: DayInfo
    let template: ShareCardView.Template
    var includeNote = false
    /// In a fixed-height (3:4) card, covers and spacing absorb the remaining height.
    var fillsHeight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if template == .polaroid { flexibleCover(height: 230) }
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("时光")
                        .foregroundStyle(Theme.accent)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    Text(CNDate.full(info.displayDate))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(Theme.sans(11))
                switch template {
                case .polaroid:
                    title
                    countdown
                    note
                case .note:
                    title
                    note
                    flexibleCover(height: 150)
                    countdown
                case .minimal:
                    title
                    if fillsHeight { Spacer(minLength: 28) }
                    countdown.padding(.vertical, 28)
                    note
                    if fillsHeight { Spacer(minLength: 0) }
                case .collage:
                    HStack(alignment: .top, spacing: 18) {
                        cover.frame(width: 108)
                            .frame(minHeight: fillsHeight ? 120 : 210, maxHeight: fillsHeight ? .infinity : 210)
                        VStack(alignment: .leading, spacing: 16) {
                            title
                            countdown
                        }
                    }
                    note
                }
            }
            .padding(22)
            // Text keeps its size; a flexible cover takes whatever height is left.
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .background(Theme.card)
        .clipped()
    }

    private var cover: some View {
        PhotoTile(day: day, flat: true, cornerRadius: 0)
    }

    /// Fixed height in a natural card; in a 3:4 card the cover takes whatever height is left.
    @ViewBuilder
    private func flexibleCover(height: CGFloat) -> some View {
        if fillsHeight {
            cover.frame(minHeight: 100, maxHeight: .infinity)
        } else {
            cover.frame(height: height)
        }
    }

    private var title: some View {
        Text(verbatim: day.title)
            .font(Theme.sans(23, weight: .medium))
            .foregroundStyle(Theme.ink)
            .lineLimit(fillsHeight ? 3 : nil)
            .fixedSize(horizontal: false, vertical: !fillsHeight)
            .layoutPriority(1)
    }

    private var countdown: some View {
        let countdownLabel = info.isToday ? String(localized: "就是今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : info.isPast ? String(localized: "\(info.days) 天前", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
            : String(localized: "\(info.days) 天后", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        let layout = template == .collage
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 6))
        return layout {
            Text(info.isToday ? String(localized: "今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : info.days.formatted())
                .font(info.isToday ? Theme.sans(34) : Theme.number(template == .minimal ? 112 : 66))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            if !info.isToday {
                Text(info.countdownUnit)
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(countdownLabel)
        .layoutPriority(1)
    }

    @ViewBuilder
    private var note: some View {
        if includeNote && !day.note.isEmpty {
            Text(verbatim: day.note)
                .font(Theme.sans(14))
                .lineSpacing(6)
                .foregroundStyle(Theme.ink2)
                .lineLimit(fillsHeight ? 4 : nil)
                .fixedSize(horizontal: false, vertical: !fillsHeight)
                .layoutPriority(1)
        }
    }
}
