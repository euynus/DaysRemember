import SwiftUI

struct WidgetsPreviewView: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var size: DayWidgetCard.Size = .medium
    @State private var lockScreen = false
    @State private var accessoryStyle: DayAccessoryWidget.Style = .rectangular
    @State private var selectedID: String?

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: String(localized: "小组件预览", bundle: AppLocalization.bundle, locale: AppLocalization.locale), onBack: { dismiss() })
            Picker("位置", selection: $lockScreen) {
                Text("主屏幕").tag(false)
                Text("锁定屏幕").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
            Picker("日子", selection: $selectedID) {
                Text("最近的日子").tag(String?.none)
                ForEach(store.days) { day in
                    Text(day.title).tag(Optional(day.id))
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("widgetPreviewDayPicker")
            .padding(.horizontal, 22)
            if lockScreen {
                Picker("样式", selection: $accessoryStyle) {
                    Text("圆形").tag(DayAccessoryWidget.Style.circular)
                    Text("矩形").tag(DayAccessoryWidget.Style.rectangular)
                    Text("行内").tag(DayAccessoryWidget.Style.inline)
                }
                .pickerStyle(.segmented)
                .padding(22)
            } else {
                Picker("尺寸", selection: $size) {
                    Text("小").tag(DayWidgetCard.Size.small)
                    Text("中").tag(DayWidgetCard.Size.medium)
                    Text("大").tag(DayWidgetCard.Size.large)
                }
                .pickerStyle(.segmented)
                .padding(22)
            }
            ScrollView {
                let day = WidgetDay.resolve(in: store.days, selectedID: selectedID, today: today)
                if lockScreen {
                    DayAccessoryWidget(day: day, style: accessoryStyle, today: today,
                                       selectionMissing: selectedID != nil && day == nil)
                        .frame(width: accessorySize.width, height: accessorySize.height)
                        .accessibilityIdentifier("accessoryWidgetPreview")
                        .padding(.vertical, 64)
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .environment(\.colorScheme, .dark)
                } else if let day {
                    DayWidgetCard(day: day, size: size, today: today)
                        .frame(width: size == .small ? 160 : 320,
                               height: size == .large ? 340 : 160)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        }
                        .padding(.vertical, 24)
                } else {
                    ContentUnavailableView(selectedID == nil ? "还没有日子" : "日子已删除", systemImage: "calendar")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
    }

    private var accessorySize: CGSize {
        switch accessoryStyle {
        case .circular: return CGSize(width: 56, height: 56)
        case .rectangular: return CGSize(width: 160, height: 56)
        case .inline: return CGSize(width: 230, height: 20)
        }
    }
}
