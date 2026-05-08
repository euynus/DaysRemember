import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: DayStore
    @State private var filter: Filter = .all
    @State private var isSearching = false
    @State private var searchText = ""
    var onOpen: (Day) -> Void = { _ in }
    var onAdd: () -> Void = {}

    enum Filter: Hashable {
        case all, pinned, category(String)
    }

    private var filters: [Filter] {
        [.all, .pinned] + store.categories.map { .category($0.id) }
    }

    private var filteredDays: [Day] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.sortedDays(store.days).filter { d in
            switch filter {
            case .all:
                break
            case .pinned:
                guard d.pinned else { return false }
            case .category(let id):
                guard d.categoryID == id else { return false }
            }
            guard !query.isEmpty else { return true }
            let categoryName = store.category(for: d).name
            return [d.title, d.location, d.note, categoryName]
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isSearching { searchField }
            chips
            TodaySpotlight(store: store, onOpen: onOpen)
            TodayStrip()
            ScrollView(.vertical, showsIndicators: false) {
                if filteredDays.isEmpty {
                    ContentUnavailableView(
                        isSearching ? "没有找到日子" : "这里还没有日子",
                        systemImage: isSearching ? "magnifyingglass" : "calendar.badge.plus",
                        description: Text(isSearching ? "换个关键词试试。" : "点右上角加号记录第一个重要日子。")
                    )
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 56)
                    .padding(.horizontal, 24)
                } else {
                    MosaicGrid(days: filteredDays, onOpen: onOpen)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }
            }
            .padding(.bottom, 96) // tab-bar clearance
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
                IconBtn(kind: .search) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isSearching.toggle()
                        if !isSearching { searchText = "" }
                    }
                }
                IconBtn(kind: .plus, accent: true, action: onAdd)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 62)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.muted)
            TextField("搜索标题、地点、备注、分类", text: $searchText)
                .font(Theme.sans(14))
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button("清除") { searchText = "" }
                    .font(Theme.sans(13, weight: .medium))
                    .foregroundStyle(Theme.terracotta)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .accessibilityLabel("搜索日子")
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { f in
                    FilterChip(label: label(for: f), active: f == filter) { filter = f }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private func label(for filter: Filter) -> String {
        switch filter {
        case .all: return "全部"
        case .pinned: return "置顶"
        case .category(let id): return store.category(for: id).name
        }
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
                        colors: [
                            .adaptive(lightOklch: (0.96, 0.02, 30), darkOklch: (0.30, 0.04, 30)),
                            .adaptive(lightOklch: (0.90, 0.04, 35), darkOklch: (0.36, 0.06, 35))
                        ],
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
