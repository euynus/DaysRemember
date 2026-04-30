import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: DayStore
    @State private var filter: Filter = .all
    var onOpen: (Day) -> Void = { _ in }
    var onAdd: () -> Void = {}

    enum Filter: Hashable {
        case all, pinned, category(DayCategory)
        var label: String {
            switch self {
            case .all: return "全部"
            case .pinned: return "置顶"
            case .category(let c): return c.label
            }
        }
    }

    private static let filters: [Filter] = [.all, .pinned, .category(.love), .category(.family),
                                            .category(.travel), .category(.work)]

    private var filteredDays: [Day] {
        store.days.filter { d in
            switch filter {
            case .all: return true
            case .pinned: return d.pinned
            case .category(let c): return d.category == c
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            chips
            TodaySpotlight(store: store, onOpen: onOpen)
            TodayStrip()
            ScrollView(.vertical, showsIndicators: false) {
                MosaicGrid(days: filteredDays, onOpen: onOpen)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 96) // tab-bar clearance
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(CNDate.short(Today.date)) · \(CNDate.weekday(Today.date))")
                    .font(Theme.sans(12))
                    .tracking(3.6)
                    .foregroundStyle(Theme.muted)
                Text("你好，今天")
                    .font(Theme.serif(30, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            HStack(spacing: 6) {
                IconBtn(kind: .search)
                IconBtn(kind: .plus, accent: true, action: onAdd)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 62)
        .padding(.bottom, 8)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.filters, id: \.self) { f in
                    FilterChip(label: f.label, active: f == filter) { filter = f }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
}

/// "Today" strip — lunar date + 节气 + 传统节日.
struct TodayStrip: View {
    var body: some View {
        let lunar = Lunar.fmtFull(Today.date)
        let term = SolarTerms.name(for: Today.date)
        let holi = SolarTerms.lunarHoliday(for: Today.date)
        return HStack(spacing: 8) {
            Text(lunar)
                .font(Theme.serif(11))
                .foregroundStyle(Theme.muted)
            if let term {
                Text("· \(term)")
                    .font(Theme.serif(11, weight: .semibold))
                    .foregroundStyle(Theme.terracotta)
            }
            if let holi {
                Text("· \(holi)")
                    .font(Theme.serif(11, weight: .semibold))
                    .foregroundStyle(Theme.terracotta)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
}

/// "即将到来" card surfaces the nearest upcoming day.
struct TodaySpotlight: View {
    var store: DayStore
    var onOpen: (Day) -> Void

    var body: some View {
        if let day = store.nearestUpcoming() {
            let info = DayInfo.compute(day)
            Button { onOpen(day) } label: {
                HStack(spacing: 14) {
                    PhotoTile(day: day, flat: true, cornerRadius: 14)
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("即将到来")
                            .font(Theme.sans(11, weight: .semibold))
                            .tracking(2.2)
                            .foregroundStyle(Theme.terracotta)
                        Text(day.title)
                            .font(Theme.sans(15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(info.days)")
                            .font(Theme.serif(28, weight: .semibold))
                            .foregroundStyle(Theme.terracotta)
                            .monospacedDigit()
                        Text("天后")
                            .font(Theme.sans(10))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(oklch: 0.96, 0.02, 30), Color(oklch: 0.90, 0.04, 35)],
                        startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
    }
}
