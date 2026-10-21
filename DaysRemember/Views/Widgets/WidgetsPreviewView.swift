import SwiftUI

struct WidgetsPreviewView: View {
    @Environment(\.currentDay) private var today
    @Environment(DayStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var size = WidgetsPreviewView.initialSize()
    @State private var lockScreen = false
    @State private var accessoryStyle: DayAccessoryWidget.Style = .rectangular
    @State private var selectedID: String?

    /// Allows `xcrun simctl launch ... --screen widgets --widget-size large` for screenshotting.
    private static func initialSize() -> DayWidgetCard.Size {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--widget-size"), i + 1 < args.count else { return .medium }
        switch args[i + 1] {
        case "small": return .small
        case "large": return .large
        default: return .medium
        }
    }

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
                    DayWidgetCard(day: day, size: size, today: today,
                                  colorToken: store.category(for: day).colorToken)
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
                if !lockScreen && size != .small {
                    listPreview
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bg)
    }

    /// The days-list widget, which lists the next few days rather than one.
    private var listPreview: some View {
        let large = size == .large
        let days = WidgetDay.list(in: store.days, today: today, limit: DayListWidgetCard.capacity(large: large))
        return VStack(spacing: 10) {
            Text("日子列表")
                .font(Theme.sans(15, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            DayListWidgetCard(days: days, large: large, today: today,
                              colorTokens: Dictionary(uniqueKeysWithValues: days.map { ($0.id, store.category(for: $0).colorToken) }))
                .frame(width: 320, height: large ? 340 : 160)
                .background(Theme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }
                .accessibilityIdentifier("listWidgetPreview")
        }
        .padding(.bottom, 24)
    }

    private var accessorySize: CGSize { Self.accessorySize(for: accessoryStyle) }

    /// The bounds a Lock Screen widget gets. In a smaller frame the layout drops the title or the
    /// date, so the preview would show a different widget from the one added.
    static func accessorySize(for style: DayAccessoryWidget.Style) -> CGSize {
        switch style {
        case .circular: return CGSize(width: 72, height: 72)
        case .rectangular: return CGSize(width: 160, height: 72)
        case .inline: return CGSize(width: 230, height: 20)
        }
    }
}
