import SwiftUI

struct DetailView: View {
    let day: Day
    var onBack: () -> Void = {}
    @State private var showShare = false

    var body: some View {
        let info = DayInfo.compute(day)

        ZStack {
            // Background photo + scrim
            ZStack {
                PhotoTile(day: day, flat: true, cornerRadius: 0)
                LinearGradient(
                    colors: [
                        .black.opacity(0.25),
                        .black.opacity(0.10),
                        .black.opacity(0.85),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topControls
                Spacer()
                counter(info: info)
                Spacer()
                infoCard(info: info)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 46)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShare) {
            ShareCardView(day: day)
        }
    }

    private var topControls: some View {
        HStack {
            GlassButton(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
            }
            Spacer()
            HStack(spacing: 8) {
                GlassButton {} content: {
                    Image(systemName: "star")
                        .font(.system(size: 14, weight: .semibold))
                }
                GlassButton {} content: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 62)
    }

    private func counter(info: DayInfo) -> some View {
        VStack(spacing: 0) {
            Text(day.categoryLabel.uppercased())
                .font(Theme.sans(11))
                .tracking(3.3)
                .foregroundStyle(Color.white.opacity(0.8))
                .padding(.bottom, 10)
            Text(day.title)
                .font(Theme.serif(28, weight: .medium))
            Text("\(info.days)")
                .font(Theme.serif(120, weight: .medium))
                .monospacedDigit()
                .padding(.top, 28)
                .padding(.bottom, 6)
            Text("\(info.label) · 天")
                .font(Theme.sans(14))
                .tracking(3.5)
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    private func infoCard(info: DayInfo) -> some View {
        VStack(spacing: 0) {
            InfoRow(label: "日期",
                    value: "\(CNDate.full(info.displayDate)) · \(CNDate.weekday(info.displayDate))")
            InfoRow(label: "农历", value: Lunar.fmtFull(info.displayDate))
            if let term = SolarTerms.name(for: info.displayDate) {
                InfoRow(label: "节气", value: term)
            }
            if let h = SolarTerms.lunarHoliday(for: info.displayDate) {
                InfoRow(label: "传统节日", value: h)
            }
            if day.lunar {
                InfoRow(label: "按农历重复", value: "每年农历相同日期")
            }
            if !day.location.isEmpty {
                InfoRow(label: "地点", value: day.location)
            }
            if day.recurring {
                let n = (info.yearsAgo ?? 0) + (info.isPast ? 0 : 1)
                InfoRow(label: "重复", value: "每年 · 第 \(n) 次")
            }
            if !day.note.isEmpty {
                Divider().background(Color.white.opacity(0.2)).padding(.top, 12)
                Text("\u{201C}\(day.note)\u{201D}")
                    .font(Theme.serif(14).italic())
                    .lineSpacing(14 * 0.7)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(Theme.sans(13))
                .foregroundStyle(Color.white.opacity(0.65))
            Spacer()
            Text(value)
                .font(Theme.sans(13, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 5)
    }
}
