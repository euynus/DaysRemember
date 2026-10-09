import SwiftUI

struct HomeView: View {
    @Environment(DayStore.self) var store
    @Environment(\.currentDay) private var today
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filter: Filter = .all
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var showingSettings = false
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
            let categoryName = store.category(for: d).displayName
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
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        if days.isEmpty {
                            let empty = emptyStateCopy()
                            ContentUnavailableView(empty.title,
                                                   systemImage: empty.symbol,
                                                   description: Text(empty.detail))
                                .foregroundStyle(Theme.muted)
                                .padding(.top, 56)
                                .padding(.horizontal, 24)
                            if filter == .all && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                                        SectionHeader(hero != nil
                                                      ? String(localized: "其他日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                                                      : filter == .all
                                                      ? String(localized: "日子清单", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                                                      : label(for: filter))
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
                    .id("home.feed.top")
                }
                .accessibilityIdentifier("home.feed")
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: filter) {
                    searchFocused = false
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        proxy.scrollTo("home.feed.top", anchor: .top)
                    }
                }
                .onChange(of: searchText) { proxy.scrollTo("home.feed.top", anchor: .top) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .sensoryFeedback(.selection, trigger: filter)
        .onChange(of: store.categories.map(\.id)) { _, ids in
            if case .category(let id) = filter, !ids.contains(id) { filter = .all }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("时光")
                    .font(Theme.sans(30, weight: .medium, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 8)
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("设置")
                .accessibilityIdentifier("home.settings")
                FAB(systemName: isSearching ? "xmark" : "magnifyingglass", size: 42) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        isSearching.toggle()
                        if !isSearching { searchText = ""; searchFocused = false }
                    }
                }
                .accessibilityLabel(isSearching
                    ? String(localized: "关闭搜索", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                    : String(localized: "搜索日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                .accessibilityIdentifier("home.search")
                FAB(systemName: "plus", size: 42, dark: true, action: onAdd)
                    .accessibilityLabel("添加日子")
                    .accessibilityIdentifier("home.addDay")
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
            MetaItem(text: String(localized: "\(CNDate.short(today)) \(CNDate.weekday(today))",
                                  bundle: AppLocalization.bundle, locale: AppLocalization.locale)),
            MetaItem(text: Lunar.fmt(today)),
        ]
        if let term = SolarTerms.name(for: today) {
            items.append(MetaItem(text: term, color: Theme.solarTerm, bold: true))
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
                .accessibilityIdentifier("home.searchField")
            if !searchText.isEmpty {
                Button("清除", systemImage: "xmark.circle.fill") { searchText = "" }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Theme.muted)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.clearSearch")
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
            HStack(spacing: 16) {
                ForEach(filters, id: \.self) { f in
                    Button { filter = f } label: {
                        Text(verbatim: label(for: f))
                            .font(Theme.sans(14, weight: f == filter ? .semibold : .regular))
                            .foregroundStyle(f == filter ? Theme.ink : Theme.muted)
                            .lineLimit(1)
                            .frame(maxWidth: 220)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
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
        case .all: return String(localized: "全部", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .pinned: return String(localized: "已置顶", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        case .category(let id): return store.category(for: id).displayName
        }
    }

    /// Copy for the empty-state placeholder, tailored to whichever filter or search
    /// is currently active so the message matches what the user is seeing.
    private func emptyStateCopy() -> (title: String, symbol: String, detail: String) {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (String(localized: "没有找到日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                    "magnifyingglass",
                    String(localized: "换个关键词试试。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        }
        switch filter {
        case .pinned:
            return (String(localized: "还没有置顶的日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                    "star",
                    String(localized: "在日子上长按可以置顶它。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        case .category(let id):
            return (String(localized: "这个分类里还没有日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                    store.category(for: id).symbolName,
                    String(localized: "切换分类，或在加号里给它添个新日子。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        case .all:
            return (String(localized: "这里还没有日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                    "calendar.badge.plus",
                    String(localized: "值得记住的，从这一天开始。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        }
    }
}
