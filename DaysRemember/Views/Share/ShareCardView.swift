import SwiftUI

struct ShareCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
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
            ScrollView {
                VStack(spacing: 0) {
                    card.frame(maxWidth: 320)
                    templatePicker.padding(.top, 18)
                    shareGrid.padding(.top, 24)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
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
        // Render onto an opaque paper margin so the exported image has filled corners
        // and room for the card's drop shadow (a bare card leaves transparent corners
        // and clips the shadow at the 320pt edge).
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
        HStack(spacing: 16) {
            Button(action: presentShareSheet) {
                Label("分享图片", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            Button(action: saveToPhotos) {
                Label("保存", systemImage: "square.and.arrow.down")
                    .frame(minHeight: 44)
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
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("时光").font(Theme.sans(13, weight: .semibold))
                Spacer()
                Text(CNDate.full(info.displayDate)).font(Theme.sans(11))
            }
            .foregroundStyle(Theme.ink2)
            Divider()
            switch template {
            case .polaroid:
                cover.frame(height: 240)
                title
                countdown
                note
            case .note:
                title
                note
                cover.frame(height: 160)
                countdown
            case .minimal:
                title
                countdown.padding(.vertical, 32)
                note
            case .collage:
                HStack(alignment: .top, spacing: 16) {
                    cover.frame(width: 110, height: 200)
                    VStack(alignment: .leading, spacing: 16) {
                        title
                        countdown
                    }
                }
                note
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
    }

    private var cover: some View {
        PhotoTile(day: day, flat: true, cornerRadius: 4)
    }

    private var title: some View {
        Text(day.title)
            .font(Theme.sans(23, weight: .bold))
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var countdown: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(info.isToday ? "今天" : "\(info.days)")
                .font(Theme.sans(template == .minimal ? 76 : 44, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            if !info.isToday {
                Text(info.isPast ? "天前" : "天后")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.ink2)
            }
        }
    }

    @ViewBuilder
    private var note: some View {
        if !day.note.isEmpty {
            Text(day.note)
                .font(Theme.sans(15))
                .lineSpacing(5)
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
