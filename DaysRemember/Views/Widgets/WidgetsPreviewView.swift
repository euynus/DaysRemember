import SwiftUI

struct WidgetsPreviewView: View {
    @Environment(DayStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var size: DayWidgetCard.Size = .medium
    @State private var selectedID: String?

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "小组件预览", onBack: { dismiss() })
            Picker("日子", selection: $selectedID) {
                Text("最近的日子").tag(String?.none)
                ForEach(store.days) { day in
                    Text(day.title).tag(Optional(day.id))
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 22)
            Picker("尺寸", selection: $size) {
                Text("小").tag(DayWidgetCard.Size.small)
                Text("中").tag(DayWidgetCard.Size.medium)
                Text("大").tag(DayWidgetCard.Size.large)
            }
            .pickerStyle(.segmented)
            .padding(22)
            ScrollView {
                if let day = WidgetDay.resolve(in: store.days, selectedID: selectedID, today: Today.date) {
                    DayWidgetCard(day: day, size: size)
                        .frame(width: size == .small ? 160 : 320,
                               height: size == .large ? 340 : 160)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        }
                        .padding(.vertical, 24)
                } else {
                    ContentUnavailableView("暂无即将到来的日子", systemImage: "calendar")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
    }
}
