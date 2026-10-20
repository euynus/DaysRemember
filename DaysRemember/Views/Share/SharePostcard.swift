import SwiftUI

struct SharePostcard: View {
    let day: Day
    let info: DayInfo
    let template: ShareCardView.Template
    var includeNote = false
    /// In a fixed-height (3:4) card, covers and spacing absorb the remaining height.
    var fillsHeight = false
    /// The day's pastel and its text colour; plain values, since an image render has no store.
    var tint: Color = Theme.noteBlue
    var ink: Color = Theme.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if template == .polaroid { flexibleCover(height: 230) }
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("时光")
                        .font(Theme.sans(11, weight: .heavy))
                        .foregroundStyle(ink)
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
        .background(template == .polaroid ? tint : Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    /// A photo fills its frame; a preset is the flat illustration on the day's pastel.
    @ViewBuilder
    private var cover: some View {
        if day.photoData != nil {
            PhotoTile(day: day, flat: true, cornerRadius: 0)
        } else {
            FlatCover(style: day.photo)
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(tint)
        }
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
            .font(Theme.sans(24, weight: .heavy))
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
            Text(info.isToday ? String(localized: "今天", bundle: AppLocalization.bundle, locale: AppLocalization.locale) : info.days.formatted(.number.locale(AppLocalization.locale)))
                .font(info.isToday ? Theme.number(34) : Theme.number(template == .minimal ? 112 : 66))
                .foregroundStyle(Theme.ink)
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
