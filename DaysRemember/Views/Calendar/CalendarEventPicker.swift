import SwiftUI

struct CalendarEventPicker: View {
    @Environment(DayStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let selection: CalendarDaySelection
    var onOpen: (Day) -> Void

    var body: some View {
        let events = selection.events(in: store.days)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Text("取消")
                            .font(Theme.sans(15, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Text(CNDate.full(selection.date))
                    .font(Theme.sans(20, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 12)

            ScrollView {
                if events.isEmpty {
                    ContentUnavailableView("当天没有日子", systemImage: "calendar")
                        .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(events) { event in
                            CalendarEventRow(day: event, onOpen: openDay)
                            RowDivider().accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
    }

    private func openDay(_ day: Day) {
        dismiss()
        onOpen(day)
    }
}
