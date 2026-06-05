import SwiftUI

// Scrapbook categories — a 2-col grid of white tilted cards, each pinned with a
// flat category sticker and a small count sticky note. The first "全部日子" card
// spans both columns and shows peek polaroids. A dashed card creates new
// categories. Faithful port of `screens/Categories.jsx`.
struct CategoriesView: View {
    @Environment(DayStore.self) var store
    var onOpen: (Day) -> Void = { _ in }

    @State private var editing = false
    @State private var showingEditor = false
    @State private var editingCategory: CategoryDefinition?
    @State private var deletingCategory: CategoryDefinition?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavHeader(title: "分类") {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { editing.toggle() }
                } label: {
                    Text(editing ? "完成" : "编辑")
                        .font(Theme.sans(15, weight: .bold))
                        .foregroundStyle(Theme.ink2)
                        .frame(minWidth: 42, minHeight: 42, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            header
            ScrollView(.vertical, showsIndicators: false) {
                grid
                addCategoryCard
                    .padding(.top, 18)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .sheet(isPresented: $showingEditor) {
            CategoryEditorView(category: editingCategory).environment(store)
        }
        .confirmationDialog("删除分类后迁移日子到哪里？",
                            isPresented: Binding(
                                get: { deletingCategory != nil },
                                set: { if !$0 { deletingCategory = nil } }
                            ),
                            titleVisibility: .visible) {
            if let deletingCategory {
                ForEach(store.categories.filter { $0.id != deletingCategory.id }) { target in
                    Button("迁移到 \(target.name)") {
                        Haptics.warning()
                        store.deleteCategory(id: deletingCategory.id, migrateTo: target.id)
                        self.deletingCategory = nil
                    }
                }
            }
            Button("取消", role: .cancel) { deletingCategory = nil }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("你的分类")
                .font(Theme.sans(32, weight: .heavy))
                .tracking(-1)
                .foregroundStyle(Theme.ink)
            MetaRow(["\(store.days.count) 个日子", "\(store.categories.count) 个分类"])
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    /// One pass over `days` keyed by category, so each tile is an O(1) lookup
    /// instead of re-filtering all days per tile.
    private var categoryCounts: [String: Int] {
        Dictionary(store.days.map { ($0.categoryID, 1) }, uniquingKeysWith: +)
    }

    private var grid: some View {
        let counts = categoryCounts
        // The hero card lives *above* the grid (not via `gridCellColumns(2)`, whose
        // width proposal to spanned content is unreliable and squeezed its label).
        return VStack(spacing: 16) {
            heroCard
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(Array(store.categories.enumerated()), id: \.element.id) { idx, category in
                    categoryTile(category, count: counts[category.id] ?? 0, index: idx + 1)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
    }

    // MARK: - Hero "全部日子" card (spans both columns, peek polaroids)

    private var heroCard: some View {
        let count = store.days.count
        return cardShell(rotation: -0.8, height: 130) {
            NavigationLink {
                CategoryDaysListView(title: "全部日子", days: store.days(in: nil), onOpen: onOpen)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 0) {
                        Sticker(name: .star, size: 46, rotate: -8)
                        Text("全部日子")
                            .font(Theme.sans(20, weight: .heavy))
                            .tracking(-0.4)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .padding(.top, 10)
                        Text("\(count) 个日子")
                            .font(Theme.sans(12, weight: .bold))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    peekPolaroids
                        .fixedSize()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScale())
            .disabled(editing)
        }
        .overlay(alignment: .topTrailing) {
            countSticky(count, note: allNoteColor)
                .padding(.trailing, 16)
                .offset(y: -2)
        }
    }

    private var peekPolaroids: some View {
        let stack: [PhotoStyle] = [.wedding, .baby, .japan]
        return HStack(spacing: -14) {
            ForEach(stack.indices, id: \.self) { j in
                PhotoTile(style: stack[j], flat: true, cornerRadius: 9)
                    .frame(width: 48, height: 48)
                    .polaroidCard(rotation: j % 2 == 1 ? 5 : -5, padding: 3)
                    .zIndex(Double(stack.count - j))
            }
        }
    }

    // MARK: - Per-category tile

    private func categoryTile(_ category: CategoryDefinition, count: Int, index: Int) -> some View {
        cardShell(rotation: index % 2 == 1 ? 0.8 : -0.8, height: 124) {
            NavigationLink {
                CategoryDaysListView(title: category.name,
                                     days: store.days(in: category.id),
                                     onOpen: onOpen)
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Sticker(name: stickerFor(category), size: 36, rotate: -8)
                    Spacer(minLength: 6)
                    Text(category.name)
                        .font(Theme.sans(16, weight: .heavy))
                        .tracking(-0.3)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(count) 个日子")
                        .font(Theme.sans(12, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScale())
            .disabled(editing)
        }
        .overlay(alignment: .topTrailing) {
            countSticky(count, note: noteColor(for: category))
                .offset(x: 6, y: -2)
        }
        .overlay(alignment: .bottomTrailing) {
            if editing && !category.isSystem {
                editControls(for: category)
                    .padding(8)
            }
        }
    }

    /// Maps a category to a flat sticker. System categories use a fixed sticker;
    /// custom categories use the sticker the user picked in the editor (stored in
    /// `category.icon` as a StickerName raw value).
    private func stickerFor(_ category: CategoryDefinition) -> StickerName {
        switch category.id {
        case "love": return .heart
        case "family": return .balloon
        case "travel": return .plane
        case "work": return .cap
        case "life": return .house
        default:
            return StickerName(rawValue: category.icon) ?? .star
        }
    }

    /// Count sticky-note color, color-matched to the category (the prototype pairs each
    /// note with the category's color family) rather than hashed.
    private func noteColor(for category: CategoryDefinition) -> NoteColor {
        switch category.colorToken {
        case .rose: return NoteColor(paper: Theme.notePink, ink: Theme.notePinkInk)
        case .amber: return NoteColor(paper: Theme.notePeach, ink: Theme.notePeachInk)
        case .dusty: return NoteColor(paper: Theme.noteBlue, ink: Theme.noteBlueInk)
        case .sage: return NoteColor(paper: Theme.noteGreen, ink: Theme.noteGreenInk)
        case .terracotta: return NoteColor(paper: Theme.notePeach, ink: Theme.notePeachInk)
        }
    }

    private var allNoteColor: NoteColor {
        NoteColor(paper: Theme.noteYellow, ink: Theme.noteYellowInk)
    }

    // MARK: - Shared card chrome

    /// White rounded-20 polaroid-ish card with soft double shadow + tilt.
    private func cardShell<Content: View>(rotation: Double, height: CGFloat,
                                          @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white)
            )
            .compositingGroup()
            .shadow(color: Color(hex: 0x15171C).opacity(0.05), radius: 1, x: 0, y: 1)
            .shadow(color: Color(hex: 0x15171C).opacity(0.07), radius: 12, x: 0, y: 8)
            .rotationEffect(.degrees(rotation))
            .padding(.top, 10)   // headroom for the sticky note / sticker overhang
    }

    private func countSticky(_ count: Int, note: NoteColor) -> some View {
        StickyNote(color: note.paper, ink: Theme.ink.opacity(0.6), rotate: 7, size: .s) {
            Text("\(count)")
                .font(Theme.sans(18, weight: .bold))
                .monospacedDigit()
        }
    }

    private func editControls(for category: CategoryDefinition) -> some View {
        HStack(spacing: 6) {
            Button {
                editingCategory = category
                showingEditor = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white))
                    .floatShadow()
            }
            .buttonStyle(PressScale(scale: 0.9))
            .accessibilityLabel("编辑\(category.name)")

            Button {
                deletingCategory = category
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.catLove)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white))
                    .floatShadow()
            }
            .buttonStyle(PressScale(scale: 0.9))
            .accessibilityLabel("删除\(category.name)")
        }
    }

    // MARK: - Dashed "新建分类" card

    private var addCategoryCard: some View {
        Button {
            editingCategory = nil
            showingEditor = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.bg2)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text("新建分类").font(Theme.sans(15, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("挑一个贴纸和颜色")
                        .font(Theme.sans(12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .foregroundStyle(Theme.hairlineStrong)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("新建分类")
    }
}
