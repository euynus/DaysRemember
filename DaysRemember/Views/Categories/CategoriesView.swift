import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var store: DayStore

    private struct CatTile {
        let id: String
        let label: String
        let icon: String
        let color: Color
        let soft: Color
        let count: Int
    }

    private var tiles: [CatTile] {
        let all = store.days
        return [
            .init(id: "all", label: "全部日子", icon: "✨",
                  color: Theme.terracotta, soft: Color(oklch: 0.95, 0.025, 35),
                  count: all.count),
            .init(id: "love", label: "爱情", icon: "♡",
                  color: Color(oklch: 0.65, 0.11, 10),
                  soft: Color(oklch: 0.95, 0.025, 10),
                  count: all.filter { $0.category == .love }.count),
            .init(id: "family", label: "家人", icon: "🏡",
                  color: Color(oklch: 0.65, 0.12, 70),
                  soft: Color(oklch: 0.95, 0.03, 70),
                  count: all.filter { $0.category == .family }.count),
            .init(id: "travel", label: "旅行", icon: "✈",
                  color: Color(oklch: 0.60, 0.09, 245),
                  soft: Color(oklch: 0.95, 0.02, 245),
                  count: all.filter { $0.category == .travel }.count),
            .init(id: "work", label: "工作·学业", icon: "✦",
                  color: Color(oklch: 0.60, 0.08, 155),
                  soft: Color(oklch: 0.95, 0.025, 155),
                  count: all.filter { $0.category == .work }.count),
            .init(id: "life", label: "生活", icon: "◐",
                  color: Theme.terracotta,
                  soft: Color(oklch: 0.95, 0.025, 35),
                  count: all.filter { $0.category == .life }.count),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            VStack(alignment: .leading, spacing: 4) {
                Text("你的分类")
                    .font(Theme.serif(30, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("共 \(store.days.count) 个日子 · 5 个分类")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)

            ScrollView(.vertical, showsIndicators: false) {
                grid
                addCategoryCard
                    .padding(.top, 24)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 96)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
    }

    private var topBar: some View {
        HStack {
            Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink).opacity(0)  // visually balanced; no parent in tab nav
            Spacer()
            Text("分类").font(Theme.serif(17, weight: .semibold))
            Spacer()
            Button("编辑") {}
                .font(Theme.sans(14, weight: .medium))
                .foregroundStyle(Theme.terracotta)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }

    private var grid: some View {
        let items = tiles
        return VStack(spacing: 10) {
            // First tile spans both columns.
            tileView(items[0], hero: true)
            ForEach(stride(from: 1, to: items.count, by: 2).map { $0 }, id: \.self) { i in
                HStack(spacing: 10) {
                    tileView(items[i], hero: false)
                    if i + 1 < items.count {
                        tileView(items[i + 1], hero: false)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func tileView(_ t: CatTile, hero: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            t.soft
            VStack(alignment: .leading, spacing: 6) {
                Text(t.icon)
                    .font(.system(size: hero ? 32 : 24))
                    .foregroundStyle(t.color)
                Text(t.label)
                    .font(Theme.serif(hero ? 20 : 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(t.count) 个日子")
                    .font(Theme.sans(12, weight: .medium))
                    .foregroundStyle(t.color)
            }
            .padding(16)

            if hero {
                stackedPhotoPeek
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                    .padding(14)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: hero ? 140 : 110)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 0.5)
        )
    }

    private var stackedPhotoPeek: some View {
        let stack: [PhotoStyle] = [.wedding, .baby, .japan]
        return HStack(spacing: -10) {
            ForEach(stack.indices, id: \.self) { i in
                PhotoTile(style: stack[i], flat: true, cornerRadius: 10)
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Theme.bg, lineWidth: 2)
                    )
                    .zIndex(Double(stack.count - i))
            }
        }
    }

    private var addCategoryCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Theme.bg2)
                Text("+").foregroundStyle(Theme.muted).font(.system(size: 18))
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text("新建分类").font(Theme.sans(14, weight: .medium))
                Text("自己定义标签和颜色").font(Theme.sans(12)).foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(Theme.hairlineStrong)
        )
    }
}
