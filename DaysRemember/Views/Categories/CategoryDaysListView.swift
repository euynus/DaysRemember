import SwiftUI

struct CategoryDaysListView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let days: [Day]
    var onOpen: (Day) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.vertical, showsIndicators: false) {
                if days.isEmpty {
                    ContentUnavailableView("没有日子", systemImage: "tray",
                                           description: Text("这个分类下暂时没有记录。"))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 72)
                } else {
                    VStack(spacing: 8) {
                        ForEach(days) { day in
                            Button { onOpen(day) } label: {
                                HStack(spacing: 12) {
                                    PhotoTile(day: day, flat: true, cornerRadius: 10)
                                        .frame(width: 42, height: 42)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(day.title)
                                            .font(Theme.sans(14, weight: .medium, relativeTo: .body))
                                            .foregroundStyle(Theme.ink)
                                        Text(CNDate.full(day.date))
                                            .font(Theme.sans(12, relativeTo: .caption))
                                            .foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.muted)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Theme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(day.title)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")
            Spacer()
            Text(title)
                .font(Theme.serif(17, weight: .semibold, relativeTo: .headline))
                .lineLimit(1)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 8)
    }
}
