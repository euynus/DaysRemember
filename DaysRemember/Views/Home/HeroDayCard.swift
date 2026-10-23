import SwiftUI

/// The large card at the top of each face: the nearest day ahead, or the past day
/// closest to a round number.
struct HeroDayCard: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let day: Day
    /// Page dots when the card sits in a pager.
    var position: (index: Int, count: Int)? = nil
    var milestone: Milestone? = nil
    var onOpen: (Day) -> Void = { _ in }

    private static let coverSide: CGFloat = 128
    private static let coverInset: CGFloat = 14
    /// The title, date and count stop 8pt short of the cover's whole frame (less the card's 20pt
    /// padding), which a photo fills and which spans their height: a long English date or a
    /// four-digit count ran into it.
    private static let coverClearance = coverSide + coverInset - 20 + 8

    var body: some View {
        let info = DayInfo.compute(day, today: today)
        let category = store.category(for: day)
        let tint = info.isPast ? Theme.memory : category.tint
        let ink = info.isPast ? Theme.memoryInk : category.tintInk
        let compact = dynamicTypeSize.isAccessibilitySize
        Button { onOpen(day) } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(day.pinned ? String(localized: "置顶 · \(category.displayName)", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                         : info.isPast ? category.displayName
                         : String(localized: "下一个 · \(category.displayName)", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                        .font(Theme.sans(12, weight: .bold))
                        .foregroundStyle(ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.72), in: Capsule())
                    Spacer(minLength: 0)
                    if let position, position.count > 1 {
                        PageDots(index: position.index, count: position.count, color: ink)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: day.title)
                        .font(Theme.sans(24, weight: .heavy, relativeTo: .title2))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(compact ? nil : 2)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 6)
                    Text(DayCardText.heroDate(day, info: info))
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.onPastel)
                        .lineLimit(compact ? nil : 2)
                    Spacer(minLength: 10)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if !info.isToday { CountLabel(info: info) }
                        CountValue(info: info, size: 68)
                    }
                }
                .padding(.trailing, compact ? 0 : Self.coverClearance)
                if let milestone {
                    MilestoneProgress(milestone: milestone, ink: ink)
                        .padding(.top, 6)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(alignment: .bottomTrailing) {
                if !compact {
                    CoverArt(day: day, photoCornerRadius: 18, maximumPixelSize: 512)
                        .frame(width: Self.coverSide, height: Self.coverSide)
                        .padding(.trailing, Self.coverInset)
                        .padding(.bottom, milestone == nil ? Self.coverInset : 44)
                }
            }
            .background(tint, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(PressableTileStyle())
        .accessibilityLabel(DayCardText.heroAccessibilityLabel(day, info: info, milestone: milestone))
        .accessibilityHint("长按可置顶、编辑或分享")
        .accessibilityIdentifier(info.isPast ? "pastHero.\(day.id)" : "upcomingDay.\(day.id)")
    }
}
