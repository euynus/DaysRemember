import SwiftUI

/// The two faces of the feed: days ahead count down, days behind count up.
enum HomeFace: String, Hashable {
    case upcoming, past

    /// Allows `xcrun simctl launch ... --face past` for screenshotting.
    static func initial() -> HomeFace {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--face"), i + 1 < args.count,
           let face = HomeFace(rawValue: args[i + 1]) { return face }
        return .upcoming
    }
}

struct HomeView: View {
    @Environment(DayStore.self) var store
    @Environment(\.currentDay) private var today
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var face: HomeFace = HomeFace.initial()
    @State private var heroPage: String?
    @State private var isSearching = false
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @ScaledMetric(relativeTo: .title2) private var heroHeight: CGFloat = 214
    var onOpen: (Day) -> Void = { _ in }
    var onAdd: () -> Void = {}

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        let sorted = store.sortedDays(store.days, today: today)
        let upcoming = sorted.filter { !DayInfo.compute($0, today: today).isPast }
        let past = sorted.filter { DayInfo.compute($0, today: today).isPast }
        VStack(spacing: 0) {
            header
            if isSearching { searchField }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if store.days.isEmpty {
                            emptyLibrary
                        } else if !query.isEmpty {
                            searchResults(sorted)
                        } else {
                            facePicker(upcoming: upcoming.count, past: past.count)
                            switch face {
                            case .upcoming: upcomingFace(upcoming)
                            case .past: pastFace(past)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                    .id("home.feed.top")
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("home.feed")
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: face) {
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
        .sensoryFeedback(.selection, trigger: face)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                MetaRow(metaItems)
                Text(String(localized: "\(CNDate.short(today)) \(CNDate.weekday(today))", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
                    .font(Theme.sans(30, weight: .heavy, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 8)
            FAB(systemName: isSearching ? "xmark" : "magnifyingglass", size: 44) {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    isSearching.toggle()
                    if !isSearching { searchText = ""; searchFocused = false }
                }
            }
            .accessibilityLabel(isSearching
                ? String(localized: "关闭搜索", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
                : String(localized: "搜索日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
            .accessibilityIdentifier("home.search")
            FAB(systemName: "plus", size: 44, dark: true, action: onAdd)
                .accessibilityLabel("添加日子")
                .accessibilityIdentifier("home.addDay")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    /// Lunar day and solar term above the date.
    private var metaItems: [MetaItem] {
        var items: [MetaItem] = [MetaItem(text: Lunar.fmt(today), color: Theme.muted, bold: true)]
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
                .font(Theme.sans(15, weight: .medium))
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
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .background(Theme.card, in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        // Focus as soon as the field is inserted, one runloop later so the responder chain
        // has the field: opening search stays a single tap.
        .onAppear { Task { @MainActor in searchFocused = true } }
    }

    // MARK: Faces

    private func facePicker(upcoming: Int, past: Int) -> some View {
        HStack(spacing: 4) {
            faceButton(.upcoming, title: String(localized: "将至 · \(upcoming)", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                       identifier: "home.face.upcoming")
            faceButton(.past, title: String(localized: "已过 · \(past)", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                       identifier: "home.face.past")
        }
        .padding(3)
        .background(Theme.bg2, in: Capsule())
    }

    private func faceButton(_ value: HomeFace, title: String, identifier: String) -> some View {
        let selected = face == value
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { face = value }
        } label: {
            Text(title)
                .font(Theme.sans(14, weight: selected ? .heavy : .medium))
                .foregroundStyle(selected ? Theme.ink : Theme.ink2)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    if selected {
                        Capsule().fill(Theme.card)
                            .shadow(color: Theme.ink.opacity(0.08), radius: 3, y: 1)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func upcomingFace(_ days: [Day]) -> some View {
        if days.isEmpty {
            emptyFace(title: String(localized: "没有将至的日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                      symbol: "sun.max",
                      detail: String(localized: "每年重复的日子和未来的日子会出现在这里。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        } else {
            let heroes = Array(days.sorted { DayInfo.compute($0, today: today).days < DayInfo.compute($1, today: today).days }.prefix(5))
            heroPager(heroes)
            if let recent = recentOccurrence {
                RecentOccurrenceBanner(day: recent.day, occurrence: recent.occurrence, onOpen: onOpen)
                    .dayContextMenu(day: recent.day)
            }
            let rest = days.filter { $0.id != heroes.first?.id }
            if !rest.isEmpty {
                sectionTitle(String(localized: "接下来", bundle: AppLocalization.bundle, locale: AppLocalization.locale), count: rest.count)
                DayGrid(days: rest, onOpen: onOpen)
            }
        }
    }

    @ViewBuilder
    private func heroPager(_ heroes: [Day]) -> some View {
        if dynamicTypeSize.isAccessibilitySize || heroes.count == 1 {
            if let first = heroes.first {
                HeroDayCard(day: first, onOpen: onOpen)
                    .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? nil : heroHeight)
                    .dayContextMenu(day: first)
            }
        } else {
            TabView(selection: Binding(get: { heroPage ?? heroes.first?.id }, set: { heroPage = $0 })) {
                ForEach(heroes.enumerated(), id: \.element.id) { index, day in
                    HeroDayCard(day: day, position: (index, heroes.count), onOpen: onOpen)
                        .dayContextMenu(day: day)
                        .tag(Optional(day.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: heroHeight)
            .onChange(of: heroes.map(\.id)) { _, ids in
                if let page = heroPage, !ids.contains(page) { heroPage = nil }
            }
        }
    }

    /// The most recent recurring day that passed within the last week.
    private var recentOccurrence: (day: Day, occurrence: RecentOccurrence)? {
        store.days
            .compactMap { day in RecentOccurrence.of(day, today: today).map { (day, $0) } }
            .min { $0.1.daysAgo < $1.1.daysAgo }
    }

    @ViewBuilder
    private func pastFace(_ days: [Day]) -> some View {
        if days.isEmpty {
            emptyFace(title: String(localized: "还没有走过的日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                      symbol: "moon",
                      detail: String(localized: "不重复的日子过去以后，会在这里一天天记着。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        } else {
            let milestones = days.compactMap { day in Milestone.next(after: day.date, today: today).map { (day, $0) } }
                .sorted { $0.1.daysUntil < $1.1.daysUntil }
            if let hero = milestones.first {
                HeroDayCard(day: hero.0, milestone: hero.1, onOpen: onOpen)
                    .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? nil : heroHeight)
                    .dayContextMenu(day: hero.0)
            }
            if milestones.count > 1 {
                milestoneStrip(Array(milestones.dropFirst().prefix(5)))
            }
            let rest = days.filter { $0.id != milestones.first?.0.id }
            if !rest.isEmpty {
                sectionTitle(String(localized: "走过的日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale), count: rest.count)
                DayGrid(days: rest, onOpen: onOpen)
            }
        }
    }

    private func milestoneStrip(_ items: [(Day, Milestone)]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0.id) { day, milestone in
                    Button { onOpen(day) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(milestone.daysUntil.formatted())
                                    .numberFont(26)
                                    .foregroundStyle(store.category(for: day).tintInk)
                                Text("天后")
                                    .font(Theme.sans(12))
                                    .foregroundStyle(Theme.muted)
                            }
                            Text(verbatim: "\(day.title) \(milestone.title)")
                                .font(Theme.sans(13, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(width: 160, alignment: .leading)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(PressableTileStyle())
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Theme.sans(17, weight: .heavy, relativeTo: .headline))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text("\(count)")
                .font(Theme.sans(12))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    // MARK: Empty and search

    private var emptyLibrary: some View {
        VStack(spacing: 12) {
            ContentUnavailableView(String(localized: "这里还没有日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                                   systemImage: "calendar.badge.plus",
                                   description: Text(String(localized: "值得记住的，从这一天开始。", bundle: AppLocalization.bundle, locale: AppLocalization.locale)))
                .foregroundStyle(Theme.muted)
            Button("记录第一个日子", systemImage: "plus", action: onAdd)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
        .padding(.top, 56)
        .frame(maxWidth: .infinity)
    }

    private func emptyFace(title: String, symbol: String, detail: String) -> some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(detail))
            .foregroundStyle(Theme.muted)
            .padding(.top, 40)
    }

    @ViewBuilder
    private func searchResults(_ sorted: [Day]) -> some View {
        let matched = sorted.filter { day in
            let categoryName = store.category(for: day).displayName
            return [day.title, day.location, day.note, categoryName]
                .contains { $0.localizedStandardContains(query) }
        }
        if matched.isEmpty {
            emptyFace(title: String(localized: "没有找到日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                      symbol: "magnifyingglass",
                      detail: String(localized: "换个关键词试试。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        } else {
            DayGrid(days: matched, onOpen: onOpen)
        }
    }
}
