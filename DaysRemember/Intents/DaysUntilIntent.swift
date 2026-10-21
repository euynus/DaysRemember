import AppIntents

/// Says how many days are left until a day, or have passed since it, without opening the app.
struct DaysUntilIntent: AppIntent {
    static let title = LocalizedStringResource("intent.daysUntil.title", defaultValue: "日子还有几天")
    static let description = IntentDescription(LocalizedStringResource("intent.daysUntil.description",
                                                                       defaultValue: "说出离一个日子还有多少天，或已经过去多少天。"))

    @Parameter(title: LocalizedStringResource("widget.day", defaultValue: "日子"))
    var day: WidgetDay

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$day)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard let stored = SharedStorage.loadLibrary().days.first(where: { $0.id == day.id }) else {
            throw DayMissing()
        }
        let info = DayInfo.compute(stored, today: Today.date)
        return .result(value: info.days, dialog: IntentDialog(stringLiteral: Self.sentence(for: stored, info: info)))
    }

    /// 「北海道旅行」还有 12 天, as the reminders put it, or how long ago a past day was.
    static func sentence(for day: Day, info: DayInfo) -> String {
        if info.isToday {
            return String(localized: "今天是「\(day.title)」", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
        if info.isPast {
            return String(localized: "「\(day.title)」已经过去 \(info.days) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
        }
        return String(localized: "「\(day.title)」还有 \(info.days) 天", bundle: AppLocalization.bundle, locale: AppLocalization.locale)
    }

    struct DayMissing: Error, CustomLocalizedStringResourceConvertible {
        var localizedStringResource: LocalizedStringResource {
            LocalizedStringResource("intent.dayMissing", defaultValue: "这个日子已被删除。")
        }
    }
}
