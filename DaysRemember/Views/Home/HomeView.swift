import SwiftUI

struct HomeView: View {
    @Environment(DayStore.self) var store
    @Environment(\.currentDay) private var today
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        let feed = Self.split(sorted, today: today)
        let upcoming = feed.upcoming
        let past = feed.past
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
                            HomeFacePicker(face: $face, upcoming: upcoming.count, past: past.count)
                            switch face {
                            case .upcoming: UpcomingFace(days: upcoming, heroPage: $heroPage, heroHeight: heroHeight, onOpen: onOpen)
                            case .past: PastFace(days: past, heroHeight: heroHeight, onOpen: onOpen)
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

    // MARK: Feed

    /// Splits the sorted feed into 将至 and 已过, computing each day once.
    private static func split(_ days: [Day], today: Date) -> (upcoming: [Day], past: [Day]) {
        var upcoming: [Day] = []
        var past: [Day] = []
        for day in days {
            if DayInfo.compute(day, today: today).isPast { past.append(day) } else { upcoming.append(day) }
        }
        return (upcoming, past)
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

    @ViewBuilder
    private func searchResults(_ sorted: [Day]) -> some View {
        let matched = sorted.filter { day in
            let categoryName = store.category(for: day).displayName
            return [day.title, day.location, day.note, categoryName]
                .contains { $0.localizedStandardContains(query) }
        }
        if matched.isEmpty {
            FeedEmptyState(title: String(localized: "没有找到日子", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                           symbol: "magnifyingglass",
                           detail: String(localized: "换个关键词试试。", bundle: AppLocalization.bundle, locale: AppLocalization.locale))
        } else {
            DayGrid(days: matched, onOpen: onOpen)
        }
    }
}
