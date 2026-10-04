import SwiftUI

struct DayReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var offsets: [Int]?
    @State private var time: DayReminderTime?
    let globalOffsets: [Int]
    let globalTime: DayReminderTime
    let onSave: ([Int]?, DayReminderTime?) -> Void

    // Keep custom mode and imported choices visible when their last toggle is cleared.
    @State private var mode: Mode
    @State private var offsetOptions: [Int]

    private enum Mode: String, CaseIterable {
        case global = "跟随全局"
        case off = "不提醒"
        case custom = "自定义"

        var label: String {
            switch self {
            case .global: return String(localized: "跟随全局")
            case .off: return String(localized: "不提醒")
            case .custom: return String(localized: "自定义")
            }
        }
    }

    init(offsets: [Int]?, time: DayReminderTime?, globalOffsets: [Int], globalTime: DayReminderTime,
         onSave: @escaping ([Int]?, DayReminderTime?) -> Void) {
        _offsets = State(initialValue: offsets)
        _time = State(initialValue: time)
        self.globalOffsets = globalOffsets
        self.globalTime = globalTime
        self.onSave = onSave

        let initialOffsets = offsets
        let initialMode: Mode
        if let initialOffsets {
            initialMode = initialOffsets.isEmpty ? .off : .custom
        } else {
            initialMode = time == nil ? .global : .custom
        }
        _mode = State(initialValue: initialMode)
        _offsetOptions = State(initialValue:
            Set([7, 3, 1, 0] + globalOffsets + (initialOffsets ?? []))
                .filter { (0...365).contains($0) }
                .sorted(by: >)
        )
    }

    var body: some View {
        NavigationStack {
            form
                .background(Theme.bg)
                .navigationTitle("日子提醒")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                            .accessibilityIdentifier("cancelDayReminders")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") {
                            onSave(offsets.map { Array(Set($0)).sorted(by: >) }, time)
                            dismiss()
                        }
                        .accessibilityIdentifier("confirmDayReminders")
                    }
                }
        }
        .presentationDetents([.large])
    }

    private var form: some View {
        Form {
            Section("提醒方式") {
                if dynamicTypeSize > .large {
                    modePicker.pickerStyle(.inline)
                } else {
                    modePicker.pickerStyle(.segmented)
                }
            }

            if mode == .custom {
                Section("提前提醒") {
                    ForEach(offsetOptions, id: \.self) { offset in
                        Toggle(offset == 0 ? String(localized: "当天提醒")
                               : String(localized: "提前 \(offset) 天"),
                               isOn: offsetBinding(for: offset))
                            .accessibilityIdentifier("dayReminderOffset\(offset)")
                    }
                }

                Section("提醒时间（北京时间）") {
                    Toggle("使用全局时间", isOn: usesGlobalTime)
                        .accessibilityIdentifier("dayReminderUsesGlobalTime")
                    DatePicker("提醒时间（北京时间）", selection: reminderTime,
                               displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .disabled(time == nil)
                        .environment(\.locale, AppLocalization.locale)
                        .environment(\.calendar, CNDate.calendar)
                        .environment(\.timeZone, CNDate.calendar.timeZone)
                        .accessibilityIdentifier("dayReminderTimePicker")
                    if !(time ?? globalTime).isValid {
                        Text("提醒时间无效")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .tint(Theme.accent)
    }

    private var modePicker: some View {
        Picker("提醒方式", selection: modeBinding) {
            ForEach(Mode.allCases, id: \.self) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .accessibilityIdentifier("dayReminderModePicker")
    }

    private var modeBinding: Binding<Mode> {
        Binding(get: { mode }, set: { newMode in
            mode = newMode
            switch newMode {
            case .global:
                offsets = nil
                time = nil
            case .off:
                offsets = []
                time = nil
            case .custom:
                if offsets == nil { offsets = globalOffsets }
            }
        })
    }

    private func offsetBinding(for offset: Int) -> Binding<Bool> {
        Binding(get: { (offsets ?? globalOffsets).contains(offset) }, set: { enabled in
            var selected = offsets ?? globalOffsets
            if enabled {
                if !selected.contains(offset) { selected.append(offset) }
            } else {
                selected.removeAll { $0 == offset }
            }
            offsets = selected
        })
    }

    private var usesGlobalTime: Binding<Bool> {
        Binding(get: { time == nil }, set: { useGlobal in
            time = useGlobal ? nil : globalTime
        })
    }

    private var reminderTime: Binding<Date> {
        Binding(get: {
            let value = time ?? globalTime
            let anchor = Date(timeIntervalSinceReferenceDate: 0)
            guard value.isValid else { return anchor }
            return CNDate.calendar.date(bySettingHour: value.hour, minute: value.minute,
                                        second: 0, of: anchor) ?? anchor
        }, set: { date in
            time = DayReminderTime(hour: CNDate.calendar.component(.hour, from: date),
                                   minute: CNDate.calendar.component(.minute, from: date))
        })
    }
}
