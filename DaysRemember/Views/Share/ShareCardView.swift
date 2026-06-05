import SwiftUI

// Scrapbook share postcard — a faithful port of `screens/Share.jsx`.
// The postcard preview is the view handed to ImageRenderer for the snapshot that
// the system share sheet and save-to-Photos consume.
struct ShareCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let day: Day
    @State private var template: Template = .polaroid
    @State private var sharing = false
    @State private var sharedImage: UIImage? = nil
    @State private var savedToast: String? = nil

    enum Template: String, CaseIterable {
        case polaroid, note, minimal, collage
        var label: String {
            switch self {
            case .polaroid: return "拍立得"; case .note: return "便利贴"
            case .minimal: return "极简"; case .collage: return "拼贴"
            }
        }
    }

    private var info: DayInfo { DayInfo.compute(day) }

    // The card that gets rendered/shared. Switches layout per template; all four
    // variants stay inside a 320-wide postcard so the snapshot is consistent.
    @ViewBuilder
    private var card: some View {
        switch template {
        case .polaroid: PostcardCard(day: day, info: info)
        case .note: NoteCard(day: day, info: info)
        case .minimal: MinimalPostcard(day: day, info: info)
        case .collage: CollagePostcard(day: day, info: info)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "分享", onBack: { dismiss() }) {
                FAB(systemName: "square.and.arrow.down", size: 42, action: saveToPhotos)
            }
            ScrollView {
                VStack(spacing: 0) {
                    card
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
        .sheet(isPresented: $sharing) {
            if let img = sharedImage {
                ShareSheet(activityItems: [img])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Render / share / save (preserved wiring)

    @MainActor
    private func renderCardImage() -> UIImage? {
        let renderer = ImageRenderer(content: card.frame(width: 320))
        renderer.scale = displayScale
        renderer.proposedSize = .init(width: 320, height: nil)
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

    // MARK: - Template chips

    private var templatePicker: some View {
        HStack(spacing: 8) {
            ForEach(Template.allCases, id: \.self) { t in
                Chip(t.label, selected: template == t) { template = t }
                    .accessibilityLabel("\(t.label)模板")
                    .accessibilityAddTraits(template == t ? [.isSelected] : [])
            }
        }
    }

    // MARK: - Share actions grid (微信 / 朋友圈 / 小红书 / 保存)

    private var shareGrid: some View {
        HStack(spacing: 12) {
            shareTile("微", label: "微信", color: Theme.catWork, action: presentShareSheet)
            shareTile("圈", label: "朋友圈", color: Theme.catTravel, action: presentShareSheet)
            shareTile("红", label: "小红书", color: Theme.catLove, action: presentShareSheet)
            shareTile("↓", label: "保存", color: Theme.ink, action: saveToPhotos)
        }
    }

    private func shareTile(_ glyph: String, label: String, color: Color,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(glyph)
                    .font(Theme.sans(18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(color))
                    .shadow(color: Theme.ink.opacity(0.12), radius: 12, x: 0, y: 4)
                Text(label).font(Theme.sans(12, weight: .semibold)).foregroundStyle(Theme.ink2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressScale(scale: 0.97))
        .accessibilityLabel(label)
    }
}

// MARK: - Postcard frame

/// White rounded-24 postcard with the handwritten "My Memory" header. Hosts the
/// per-template inner content.
private struct Postcard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("My Memory")
                    .font(Theme.hand(26))
                    .foregroundStyle(Theme.catTravel)
                Spacer()
                Text("时光")
                    .font(Theme.sans(11, weight: .heavy))
                    .tracking(1.3)
                    .foregroundStyle(Theme.muted)
            }
            .padding(.bottom, 12)
            content()
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white))
        .compositingGroup()
        .shadow(color: Theme.ink.opacity(0.06), radius: 1, x: 0, y: 1)
        .shadow(color: Theme.ink.opacity(0.12), radius: 20, x: 0, y: 14)
    }
}

// MARK: - Template: 拍立得 (default scrapbook postcard)

private struct PostcardCard: View {
    let day: Day; let info: DayInfo
    var body: some View {
        let nc = noteColorFor(day.id)
        Postcard {
            VStack(spacing: 6) {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        PhotoTile(day: day, cornerRadius: 12).frame(height: 260)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(day.title)
                                .font(Theme.sans(18, weight: .heavy))
                                .tracking(-0.3)
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(enDate(info.displayDate))
                                .font(Theme.hand(22))
                                .foregroundStyle(Theme.ink2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 6)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    }
                    .polaroidCard(rotation: -2)
                    .frame(width: 230)

                    // Overlays: countdown sticky note + two stickers.
                    .overlay(alignment: .topTrailing) {
                        StickyNote(color: nc.paper, ink: nc.ink, rotate: 7, clip: true, size: .s) {
                            VStack(spacing: 0) {
                                Text("\(info.days)")
                                    .font(Theme.sans(30, weight: .bold))
                                    .monospacedDigit()
                                Text(info.isPast ? "天了" : "天后")
                                    .font(Theme.handCN(15))
                            }
                        }
                        .offset(x: 6, y: 8)
                    }
                    .overlay(alignment: .bottomLeading) {
                        Sticker(name: stickerFor(day), size: 40, rotate: -12)
                            .offset(x: -8, y: -24)
                    }
                    .overlay(alignment: .topLeading) {
                        Sticker(name: .star, size: 28, rotate: 10)
                            .offset(x: 14, y: 28)
                    }
                }
                .frame(width: 230)
                .padding(.top, 6)

                if !day.note.isEmpty {
                    Text("「\(day.note)」")
                        .font(Theme.handCN(19))
                        .foregroundStyle(Color(hex: 0x3A3A3A))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Template: 便利贴 (sticky-note forward)

private struct NoteCard: View {
    let day: Day; let info: DayInfo
    var body: some View {
        let nc = noteColorFor(day.id)
        Postcard {
            VStack(spacing: 16) {
                ZStack(alignment: .topTrailing) {
                    PhotoTile(day: day, cornerRadius: 16).frame(height: 180)
                    Tape(width: 70).offset(y: -10)
                }
                StickyNote(color: nc.paper, ink: nc.ink, rotate: -3, size: .l) {
                    VStack(spacing: 4) {
                        Text(day.title).font(Theme.sans(16, weight: .bold)).foregroundStyle(nc.ink)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(info.days)")
                                .font(Theme.sans(40, weight: .bold))
                                .monospacedDigit()
                            Text(info.isPast ? "天了" : "天后")
                                .font(Theme.handCN(20))
                        }
                        if !day.note.isEmpty {
                            Text("「\(day.note)」")
                                .font(Theme.handCN(16))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }
}

// MARK: - Template: 极简

private struct MinimalPostcard: View {
    let day: Day; let info: DayInfo
    var body: some View {
        Postcard {
            VStack(alignment: .leading, spacing: 10) {
                Text(enDate(info.displayDate))
                    .font(Theme.hand(22))
                    .foregroundStyle(Theme.catTravel)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(info.days)")
                        .font(Theme.sans(96, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Text(info.isPast ? "天前" : "天后")
                        .font(Theme.handCN(22))
                        .foregroundStyle(Theme.ink2)
                }
                Text(day.title)
                    .font(Theme.sans(20, weight: .bold))
                    .foregroundStyle(Theme.ink)
                if !day.note.isEmpty {
                    Text("「\(day.note)」")
                        .font(Theme.handCN(17))
                        .foregroundStyle(Color(hex: 0x3A3A3A))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
        }
    }
}

// MARK: - Template: 拼贴

private struct CollagePostcard: View {
    let day: Day; let info: DayInfo
    var body: some View {
        let nc = noteColorFor(day.id)
        Postcard {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    VStack(spacing: 0) {
                        PhotoTile(day: day, cornerRadius: 12).frame(height: 150)
                    }
                    .polaroidCard(rotation: -3)
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 8) {
                        PhotoTile(style: day.photo, cornerRadius: 10).frame(height: 70)
                        StickyNote(color: nc.paper, ink: nc.ink, rotate: 5, size: .s) {
                            VStack(spacing: 0) {
                                Text("\(info.days)")
                                    .font(Theme.sans(24, weight: .bold))
                                    .monospacedDigit()
                                Text(info.isPast ? "天了" : "天后")
                                    .font(Theme.handCN(13))
                            }
                        }
                    }
                    .frame(width: 96)
                }
                .overlay(alignment: .topTrailing) {
                    Sticker(name: stickerFor(day), size: 34, rotate: 12)
                        .offset(x: 6, y: -10)
                }

                VStack(spacing: 1) {
                    Text(day.title)
                        .font(Theme.sans(16, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(enDate(info.displayDate))
                        .font(Theme.hand(20))
                        .foregroundStyle(Theme.ink2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
        }
    }
}
