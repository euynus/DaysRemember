import SwiftUI

struct ShareCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let day: Day
    @State private var template: Template = .classic
    @State private var sharing = false
    @State private var sharedImage: UIImage? = nil
    @State private var savedToast: String? = nil

    enum Template: String, CaseIterable {
        case classic, frame, minimal, collage
        var label: String {
            switch self {
            case .classic: return "经典"; case .frame: return "相框"
            case .minimal: return "极简"; case .collage: return "拼贴"
            }
        }
    }

    private var info: DayInfo { DayInfo.compute(day) }

    @ViewBuilder
    private var card: some View {
        switch template {
        case .classic: ClassicCard(day: day, info: info)
        case .frame: FrameCard(day: day, info: info)
        case .minimal: MinimalCard(day: day, info: info)
        case .collage: CollageCard(day: day, info: info)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Spacer()
            card.padding(.horizontal, 32)
            Spacer()
            templatePicker
            shareRow.padding(.bottom, 36)
        }
        .background(Theme.bg2)
        .sensoryFeedback(.selection, trigger: template)
        .overlay(alignment: .top) {
            if let savedToast {
                Text(savedToast)
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.78))
                    .clipShape(Capsule())
                    .padding(.top, 60)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $sharing) {
            if let img = sharedImage {
                ShareSheet(activityItems: [img])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    @MainActor
    private func renderCardImage() -> UIImage? {
        let renderer = ImageRenderer(content: card.frame(width: 280, height: 350))
        renderer.scale = displayScale
        renderer.proposedSize = .init(width: 280, height: 350)
        return renderer.uiImage
    }

    private func presentShareSheet() {
        guard let img = renderCardImage() else { return }
        sharedImage = img
        sharing = true
    }

    private func saveToPhotos() {
        guard let img = renderCardImage() else { return }
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

    private var navBar: some View {
        HStack {
            Button("取消") { dismiss() }
                .font(Theme.sans(15, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .buttonStyle(.plain)
                .navTextButton()
            Spacer()
            Text("分享").font(Theme.serif(17, weight: .semibold))
            Spacer()
            Button("保存", action: saveToPhotos)
                .font(Theme.sans(15, weight: .semibold))
                .foregroundStyle(Theme.terracotta)
                .buttonStyle(.plain)
                .navTextButton()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    private var templatePicker: some View {
        HStack(spacing: 8) {
            ForEach(Template.allCases, id: \.self) { t in
                Button {
                    template = t
                } label: {
                    Text(t.label)
                        .font(Theme.sans(12, weight: .medium))
                        .foregroundStyle(template == t ? Theme.terracotta : Theme.ink2)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(template == t ? Theme.terracottaSoft : Theme.card)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(template == t ? Theme.terracotta.opacity(0.22) : Theme.hairline,
                                              lineWidth: 0.5)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(t.label)模板")
                .accessibilityAddTraits(template == t ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 14)
    }

    private var shareRow: some View {
        HStack(spacing: 18) {
            shareIcon("square.and.arrow.up", color: Theme.terracotta, label: "分享",
                      action: presentShareSheet)
            shareIcon("square.and.arrow.down", color: Theme.ink, label: "保存",
                      action: saveToPhotos)
            shareIcon("ellipsis", color: Theme.ink2, label: "更多",
                      action: presentShareSheet)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private func shareIcon(_ systemName: String, color: Color, label: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.92))
                    Image(systemName: systemName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                Text(label).font(Theme.sans(11)).foregroundStyle(Theme.ink2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
    }
}

struct ClassicCard: View {
    let day: Day; let info: DayInfo
    var body: some View {
        ZStack(alignment: .topLeading) {
            PhotoTile(day: day, cornerRadius: 18)
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(day.categoryLabel)
                        .font(Theme.sans(11)).tracking(3.3)
                        .foregroundStyle(Color.white.opacity(0.8))
                    Text(day.title)
                        .font(Theme.serif(22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(info.days)")
                        .font(Theme.serif(78, weight: .medium))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("\(info.isPast ? "已经" : "还有") · 天")
                        .font(Theme.sans(12))
                        .tracking(2.4)
                        .foregroundStyle(Color.white.opacity(0.8))
                    Divider().background(Color.white.opacity(0.3)).padding(.top, 14)
                    Text("SHIGUANG · 时光")
                        .font(Theme.sans(10))
                        .tracking(2)
                        .foregroundStyle(Color.white.opacity(0.65))
                        .padding(.top, 14)
                }
            }
            .padding(22)
        }
        .frame(width: 280, height: 350)
        .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
    }
}

struct FrameCard: View {
    let day: Day; let info: DayInfo
    var body: some View {
        VStack(spacing: 14) {
            PhotoTile(day: day, cornerRadius: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 4) {
                Text(day.title)
                    .font(Theme.serif(16, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1F1A15))
                Text("第 \(info.days) 天")
                    .font(Theme.serif(32, weight: .medium))
                    .foregroundStyle(Color(oklch: 0.62, 0.12, 35))
                    .monospacedDigit()
                Text(CNDate.full(day.date))
                    .font(Theme.sans(10))
                    .tracking(2)
                    .foregroundStyle(Color(hex: 0x8A8074))
            }
            .padding(.bottom, 4)
        }
        .padding(12)
        .frame(width: 280, height: 350)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
    }
}

struct MinimalCard: View {
    let day: Day; let info: DayInfo
    var body: some View {
        VStack(alignment: .leading) {
            Text("时光 · \(CNDate.full(day.date))")
                .font(Theme.sans(10))
                .tracking(3)
                .foregroundStyle(Theme.muted)
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text("\(info.days)")
                    .font(Theme.serif(110, weight: .medium))
                    .foregroundStyle(Theme.terracotta)
                    .monospacedDigit()
                Text("\(info.isPast ? "已经过去" : "还有") · 天")
                    .font(Theme.serif(13))
                    .tracking(2.6)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(day.title)
                .font(Theme.serif(18, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(28)
        .frame(width: 280, height: 350, alignment: .topLeading)
        .background(Theme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
    }
}

struct CollageCard: View {
    let day: Day; let info: DayInfo
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                PhotoTile(day: day, cornerRadius: 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: 6) {
                    PhotoTile(style: .baby, cornerRadius: 12)
                    PhotoTile(style: .japan, cornerRadius: 12)
                }
                .frame(width: 78)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(day.title).font(Theme.serif(16, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text("\(info.days)")
                    .font(Theme.serif(28, weight: .medium))
                    .foregroundStyle(Color(oklch: 0.78, 0.13, 35))
                    .monospacedDigit()
            }
            Text("\(CNDate.full(day.date)) · 时光")
                .font(Theme.sans(10))
                .tracking(2)
                .foregroundStyle(Color.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(width: 280, height: 350)
        .background(Theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
    }
}
