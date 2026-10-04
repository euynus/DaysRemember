import SwiftUI

struct HomeView: View {
    @Environment(DayStore.self) var store
    @Environment(\.currentDay) private var today
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filter: Filter = .all
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var showingWidgets = false
    @State private var showingData = false
    @FocusState private var searchFocused: Bool
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
        return store.sortedDays(matched, today: today)
    }

    var body: some View {
        let days = filteredDays
        let hero = filter == .all && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? store.nearestUpcoming(within: .max, today: today) : nil
        let feedDays = days.filter { $0.id != hero?.id }
        VStack(spacing: 0) {
            header
            if isSearching { searchField }
            chips
            ScrollView(.vertical, showsIndicators: false) {
                if days.isEmpty {
                    let empty = emptyStateCopy()
                    ContentUnavailableView(empty.title,
                                           systemImage: empty.symbol,
                                           description: Text(empty.detail))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 56)
                        .padding(.horizontal, 24)
                    if filter == .all && searchText.isEmpty {
                        Button("记录第一个日子", systemImage: "plus", action: onAdd)
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .padding(.top, 12)
                    }
                } else {
                    VStack(spacing: 0) {
                        if let hero {
                            UpcomingDayView(day: hero, onOpen: onOpen)
                                .dayContextMenu(day: hero)
                                .padding(.bottom, feedDays.isEmpty ? 0 : 26)
                        }
                        if !feedDays.isEmpty {
                            HStack {
                                SectionHeader(hero != nil ? "其他日子" : filter == .all ? "日子清单" : label(for: filter))
                                Text("\(feedDays.count)")
                                    .font(Theme.sans(12))
                                    .foregroundStyle(Theme.muted)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 10)
                            DayList(days: feedDays, onOpen: onOpen)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .sensoryFeedback(.selection, trigger: filter)
        .sheet(isPresented: $showingWidgets) { WidgetsPreviewView() }
        .sheet(isPresented: $showingData) { DataManagementView() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("时光")
                    .font(Theme.sans(30, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 8)
                Menu {
                    Button("小组件", systemImage: "rectangle.3.group") { showingWidgets = true }
                    Button("数据与同步", systemImage: "externaldrive") { showingData = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("日子选项")
                FAB(systemName: isSearching ? "xmark" : "magnifyingglass", size: 42) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        isSearching.toggle()
                        if !isSearching { searchText = ""; searchFocused = false }
                    }
                }
                .accessibilityLabel(isSearching ? "关闭搜索" : "搜索日子")
                FAB(systemName: "plus", size: 42, dark: true, action: onAdd)
                    .accessibilityLabel("添加日子")
            }
            MetaRow(metaItems)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    /// Today's date · lunar day · solar term (colored) — the JSX header `.meta` line.
    private var metaItems: [MetaItem] {
        var items: [MetaItem] = [
            MetaItem(text: "\(CNDate.short(today)) \(CNDate.weekday(today))"),
            MetaItem(text: Lunar.fmt(today)),
        ]
        if let term = SolarTerms.name(for: today) {
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
                .onSubmit { searchFocused = false }
                .accessibilityLabel("搜索日子")
            if !searchText.isEmpty {
                Button("清除", systemImage: "xmark.circle.fill") { searchText = "" }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Theme.muted)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        // Focus + raise the keyboard as soon as the field is inserted, so opening
        // search is a single tap instead of tap-to-reveal then tap-to-type. Defer
        // one runloop: setting @FocusState synchronously in the .onAppear of a
        // just-inserted field races the responder chain and often no-ops on iOS 17.
        .onAppear { Task { @MainActor in searchFocused = true } }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(filters, id: \.self) { f in
                    Button { filter = f } label: {
                        Text(label(for: f))
                            .font(Theme.sans(14, weight: f == filter ? .semibold : .regular))
                            .foregroundStyle(f == filter ? Theme.ink : Theme.muted)
                            .frame(minHeight: 44)
                            .overlay(alignment: .bottom) {
                                if f == filter {
                                    Rectangle().fill(Theme.accent).frame(height: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(f == filter ? .isSelected : [])
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollClipDisabled()
        .overlay(alignment: .bottom) { RowDivider() }
        .padding(.bottom, 4)
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
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ("没有找到日子", "magnifyingglass", "换个关键词试试。")
        }
        switch filter {
        case .pinned:
            return ("还没有置顶的日子", "star", "在日子上长按可以置顶它。")
        case .category(let id):
            return ("这个分类里还没有日子",
                    store.category(for: id).symbolName,
                    "切换分类，或在加号里给它添个新日子。")
        case .all:
            return ("这里还没有日子",
                    "calendar.badge.plus",
                    "值得记住的，从这一天开始。")
        }
    }
}
