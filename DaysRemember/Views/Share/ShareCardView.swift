import SwiftUI

struct ShareCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: Day
    @State private var template: Template = .polaroid
    @State private var sharedImage: SharedImage?
    @State private var savedToast: String? = nil

    enum Template: String, CaseIterable {
        case polaroid, note, minimal, collage
        var label: String {
            switch self {
            case .polaroid: return "照片"; case .note: return "手记"
            case .minimal: return "极简"; case .collage: return "双栏"
            }
        }
    }

    private struct SharedImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private var info: DayInfo { DayInfo.compute(day) }

    private var card: some View {
        SharePostcard(day: day, info: info, template: template)
    }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "分享", onBack: { dismiss() }) {
                FAB(systemName: "square.and.arrow.down", size: 42, action: saveToPhotos)
                    .accessibilityLabel("保存到相册")
            }
            templatePicker
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            ScrollView {
                VStack(spacing: 0) {
                    card.frame(maxWidth: 320)
                        .environment(\.dynamicTypeSize, .large)
                        .shadow(color: Theme.ink.opacity(0.06), radius: 12, y: 5)
                }
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
                Text(savedToast)
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.ink.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.top, 60)
                    .transition(.opacity)
            }
        }
        .sheet(item: $sharedImage) { item in
            ShareSheet(activityItems: [item.image])
        }
    }

    // MARK: - Render / share / save (preserved wiring)

    @MainActor
    private func renderCardImage() -> UIImage? {
        // Keep the printed card and its on-screen preview at the same text scale.
        let content = card.frame(width: 320).padding(24).background(Theme.bg)
            .environment(\.dynamicTypeSize, .large)
        let renderer = ImageRenderer(content: content)
        renderer.scale = displayScale
        renderer.proposedSize = .init(width: 320 + 48, height: nil)
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func presentShareSheet() {
        guard let img = renderCardImage() else {
            Haptics.warning()
            flashToast("生成失败，请重试")
            return
        }
        sharedImage = SharedImage(image: img)
    }

    private func saveToPhotos() {
        guard let img = renderCardImage() else {
            Haptics.warning()
            flashToast("生成失败，请重试")
            return
        }
        Task {
            do {
                try await PhotoSaver.save(image: img)
                Haptics.success()
                flashToast("已保存到相册")
            } catch PhotoSaver.SaveError.denied {
                Haptics.warning()
                flashToast("无相册权限")
            } catch {
                Haptics.warning()
                flashToast("保存失败")
            }
        }
    }

    @MainActor
    private func flashToast(_ text: String) {
        withAnimation(.easeInOut(duration: 0.18)) { savedToast = text }
        Task {
            try? await Task.sleep(for: .milliseconds(1700))
            withAnimation(.easeInOut(duration: 0.25)) { savedToast = nil }
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if template == .polaroid { cover.frame(height: 230) }
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("时光").foregroundStyle(Theme.accent)
                    Spacer()
                    Text(CNDate.full(info.displayDate)).foregroundStyle(Theme.muted)
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
                    cover.frame(height: 150)
                    countdown
                case .minimal:
                    title
                    countdown.padding(.vertical, 28)
                    note
                case .collage:
                    HStack(alignment: .top, spacing: 18) {
                        cover.frame(width: 108, height: 210)
                        VStack(alignment: .leading, spacing: 16) {
                            title
                            countdown
                        }
                    }
                    note
                }
                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
    }

    private var cover: some View {
        PhotoTile(day: day, flat: true, cornerRadius: 0)
    }

    private var title: some View {
        Text(day.title)
            .font(Theme.sans(23, weight: .medium))
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var countdown: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(info.isToday ? "今天" : "\(info.days)")
                .font(info.isToday ? Theme.sans(34) : Theme.number(template == .minimal ? 112 : 66))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            if !info.isToday {
                Text(info.isPast ? "天前" : "天后")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    @ViewBuilder
    private var note: some View {
        if !day.note.isEmpty {
            Text(day.note)
                .font(Theme.sans(14))
                .lineSpacing(6)
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
