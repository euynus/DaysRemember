import SwiftUI

struct HomeView: View {
    @Environment(DayStore.self) var store
    @State private var filter: Filter = .all
    @State private var isSearching = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    var onOpen: (Day) -> Void = { _ in }
    var onAdd: () -> Void = {}

    enum Filter: Hashable {
        case all, pinned, category(String)
    }

    private var filters: [Filter] {
        [.all, .pinned] + store.categories.filter(\.isSystem).map { .category($0.id) }
    }

    private var filteredDays: [Day] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Filter first, then sort: a typed search or category filter can prune most of
        // the array, and sortedDays does an O(N log N) sort on whatever it receives.
        let matched = store.days.filter { d in
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
                .contains { $0.localizedStandardContains(query) }
        }
        return store.sortedDays(matched)
    }

    /// Nearest upcoming (future or today), uncapped — mirrors the JSX hero pick.
    private var hero: Day? {
        store.days
            .map { ($0, DayInfo.compute($0)) }
            .filter { !$0.1.isPast }
            .min { $0.1.days < $1.1.days }?
            .0
    }

    /// Feed days for the current filter, with the hero removed when it's on screen.
    private var feedDays: [Day] {
        guard filter == .all, let hero, searchText.isEmpty else { return filteredDays }
        return filteredDays.filter { $0.id != hero.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isSearching { searchField }
            chips
            ScrollView(.vertical, showsIndicators: false) {
                if filteredDays.isEmpty {
                    let empty = emptyStateCopy()
                    ContentUnavailableView(empty.title,
                                           systemImage: empty.symbol,
                                           description: Text(empty.detail))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 56)
                        .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 0) {
                        if filter == .all, searchText.isEmpty, let hero {
                            HeroPolaroid(day: hero, onOpen: onOpen)
                                .dayContextMenu(day: hero)
                                .padding(.bottom, feedDays.isEmpty ? 0 : 26)
                        }
                        if !feedDays.isEmpty {
                            MosaicGrid(days: feedDays, onOpen: onOpen)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 4)
                    .padding(.bottom, 130) // floating tab-bar clearance
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .sensoryFeedback(.selection, trigger: filter)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("你好，今天")
                    .font(Theme.sans(34, weight: .heavy))
                    .tracking(-1)
                    .foregroundStyle(Theme.ink)
                MetaRow(metaItems)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                FAB(systemName: "magnifyingglass", size: 42) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isSearching.toggle()
                        if !isSearching { searchText = "" }
                    }
                }
                FAB(systemName: "plus", size: 42, dark: true, action: onAdd)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 22)
        .padding(.top, 60)
        .padding(.bottom, 6)
    }

    /// Today's date · lunar day · solar term (colored) — the JSX header `.meta` line.
    private var metaItems: [MetaItem] {
        var items: [MetaItem] = [
            MetaItem(text: "\(CNDate.short(Today.date)) \(CNDate.weekday(Today.date))"),
            MetaItem(text: Lunar.fmt(Today.date)),
        ]
        if let term = SolarTerms.name(for: Today.date) {
            items.append(MetaItem(text: term, color: Theme.catTravel, bold: true))
        }
        return items
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.muted)
            TextField("搜索标题、地点、备注、分类", text: $searchText)
                .font(Theme.sans(14, weight: .medium))
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button("清除") { searchText = "" }
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.catLove)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .accessibilityLabel("搜索日子")
        // Focus + raise the keyboard as soon as the field is inserted, so opening
        // search is a single tap instead of tap-to-reveal then tap-to-type. Defer
        // one runloop: setting @FocusState synchronously in the .onAppear of a
        // just-inserted field races the responder chain and often no-ops on iOS 17.
        .onAppear { Task { @MainActor in searchFocused = true } }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(filters, id: \.self) { f in
                    Chip(label(for: f), selected: f == filter) { filter = f }
                }
            }
            .padding(.horizontal, 22)
        }
        .scrollClipDisabled()
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private func label(for filter: Filter) -> String {
        switch filter {
        case .all: return "全部"
        case .pinned: return "置顶"
        case .category(let id): return store.category(for: id).name
        }
    }

    /// Copy for the empty-state placeholder, tailored to whichever filter or search
    /// is currently active so the message matches what the user is seeing.
    private func emptyStateCopy() -> (title: String, symbol: String, detail: String) {
        if isSearching {
            return ("没有找到日子", "magnifyingglass", "换个关键词试试。")
        }
        switch filter {
        case .pinned:
            return ("还没有置顶的日子", "star", "在日子上长按可以置顶它。")
        case .category(let id):
            return ("这个分类里还没有日子",
                    store.category(for: id).icon,
                    "切换分类，或在加号里给它添个新日子。")
        case .all:
            return ("这里还没有日子",
                    "calendar.badge.plus",
                    "点右上角加号，记录第一个重要日子。")
        }
    }
}
