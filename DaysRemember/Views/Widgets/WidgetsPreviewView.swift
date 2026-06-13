import SwiftUI

// Scrapbook widgets gallery (preview only). Polaroid widgets float on a soft
// wallpaper gradient; the size chips swap between 中 (one wide polaroid),
// 小 (two small polaroids), and 大 (one big polaroid). Days are sourced from the
// store (wedding / japan, falling back to whatever is present).
struct WidgetsPreviewView: View {
    @Environment(DayStore.self) private var store

    @State private var size: WSize = .m
    enum WSize: String, CaseIterable { case s, m, l
        var label: String { ["s": "小", "m": "中", "l": "大"][rawValue] ?? "" }
    }

    var onBack: () -> Void = {}

    // Source days for the previews — prefer the prototype's wedding/japan picks.
    private var pinned: Day {
        store.days.first { $0.id == "wedding" } ?? store.days.first { $0.pinned } ?? store.days.first ?? SampleData.days[0]
    }
    private var up: Day {
        store.days.first { $0.id == "japan" }
            ?? store.nearestUpcoming()
            ?? store.days.first { $0.id != pinned.id }
            ?? pinned
    }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "小组件", onBack: onBack)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("放到主屏上")
                            .font(Theme.sans(30, weight: .heavy))
                            .tracking(-0.9)
                            .foregroundStyle(Theme.ink)
                        Text("每次解锁，都和重要的日子打个招呼。")
                            .font(Theme.sans(14, weight: .medium))
                            .foregroundStyle(Theme.ink2)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 4)

                    HStack(spacing: 8) {
                        ForEach(WSize.allCases, id: \.self) { s in
                            Chip("\(s.label)号", selected: size == s) { size = s }
                        }
                    }
                    .padding(.top, 14)

                    wallpaperBoard
                        .padding(.top, 12)

                    SectionHeader("风格")
                        .padding(.top, 22)
                    styleSwatches
                        .padding(.top, 12)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 120)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
    }

    // MARK: - Wallpaper board

    private var wallpaperBoard: some View {
        VStack(spacing: 0) {
            Group {
                switch size {
                case .m: mediumWidget
                case .s: smallWidgets
                case .l: largeWidget
                }
            }
            .frame(maxWidth: .infinity)

            Text("主屏预览")
                .font(Theme.sans(12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.8))
                .padding(.top, 18)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(oklch: 0.86, 0.06, 240), Color(oklch: 0.70, 0.08, 255)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    // 中 — one wide polaroid of the pinned day with a big countdown + ring sticker
    // and a "7年啦" sticky note clipped to the corner.
    private var mediumWidget: some View {
        let info = DayInfo.compute(pinned)
        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    PhotoTile(day: pinned, cornerRadius: 12)
                        .frame(height: 130)
                    Text(pinned.title)
                        .font(Theme.sans(16, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.leading, 12)
                        .padding(.bottom, 10)
                }
                HStack(alignment: .center) {
                    HStack(alignment: .lastTextBaseline, spacing: 5) {
                        Text("\(info.days)")
                            .font(Theme.sans(40, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                        // Match the real widget's copy: "已相伴" only fits a day
                        // counting up; a future anniversary counts down.
                        Text(info.isPast ? "天 · 已相伴" : "天后")
                            .font(Theme.sans(13, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Sticker(name: stickerFor(pinned), size: 32, rotate: 8)
                }
                .padding(.horizontal, 6)
                .padding(.top, 10)
                .padding(.bottom, 2)
            }
            .frame(width: 280)
            .polaroidCard(rotation: -1.5)

            if let n = info.anniversaryNumber {
                StickyNote(color: Theme.notePink, ink: Theme.notePinkInk, rotate: 8, size: .s) {
                    Text("\(n)年啦")
                }
                .offset(x: 6, y: -6)
            }
        }
    }

    // 小 — two small polaroids (japan + wedding) each with a corner sticker.
    private var smallWidgets: some View {
        HStack(spacing: 16) {
            smallPolaroid(up, rotation: -2)
            smallPolaroid(pinned, rotation: 2)
        }
    }

    private func smallPolaroid(_ day: Day, rotation: Double) -> some View {
        let info = DayInfo.compute(day)
        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                PhotoTile(day: day, flat: true, cornerRadius: 12)
                    .frame(width: 108, height: 96)
                Text("\(info.days)")
                    .font(Theme.sans(30, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
            }
            .frame(width: 124)
            .polaroidCard(rotation: rotation)

            Sticker(name: stickerFor(day), size: 30, rotate: 10)
                .offset(x: 10, y: -8)
        }
    }

    // 大 — one big polaroid of the trip with a large catTravel countdown.
    private var largeWidget: some View {
        let info = DayInfo.compute(up)
        return VStack(spacing: 0) {
            PhotoTile(day: up, flat: true, cornerRadius: 12)
                .frame(height: 180)
            VStack(alignment: .leading, spacing: 4) {
                Text(up.title)
                    .font(Theme.sans(16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(info.days)")
                        .font(Theme.sans(52, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Theme.catTravel)
                    Text(largeTrailing)
                        .font(Theme.sans(14, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
        .frame(width: 280)
        .polaroidCard(rotation: -1)
    }

    private var largeTrailing: String {
        let info = DayInfo.compute(up)
        let suffix = info.isPast ? "天前" : "天后"
        let loc = up.location.split(separator: "·").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return loc.isEmpty ? suffix : "\(suffix) · \(loc)"
    }

    // MARK: - Style swatches

    private var styleSwatches: some View {
        HStack(spacing: 12) {
            styleSwatch("拍立得", color: Theme.noteBlue, outlined: true)
            styleSwatch("便利贴", color: Theme.noteYellow, outlined: false)
            styleSwatch("极简", color: Color.white, outlined: false)
        }
    }

    private func styleSwatch(_ label: String, color: Color, outlined: Bool) -> some View {
        Text(label)
            .font(Theme.sans(13, weight: .bold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 84, alignment: .bottomLeading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color))
            .overlay {
                if outlined {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.ink, lineWidth: 2.5)
                        .padding(-2)
                }
            }
            .shadow(color: Color(hex: 0x15171C).opacity(0.06), radius: 1, x: 0, y: 1)
    }
}
