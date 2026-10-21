import Contacts
import Foundation

/// Birthdays in Contacts, offered as yearly days. Contacts is read only while the user imports,
/// and nothing of a contact but its name and birthday is kept.
enum ContactBirthdays {
    struct Candidate: Identifiable, Equatable {
        /// The contact's identifier, remembered once imported.
        let id: String
        let day: Day
    }

    private static let importedKey = "importedContactBirthdays.v1"

    static func requestAccess() async -> Bool {
        (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
    }

    /// Contacts with a birthday, leaving out those imported before and those the library already
    /// has a day for. Off the main actor: enumerating a large address book takes a while.
    @concurrent static func candidates(today: Date, library: [Day],
                                       imported: Set<String>) async throws -> [Candidate] {
        let keys: [CNKeyDescriptor] = [CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                                       CNContactBirthdayKey as CNKeyDescriptor,
                                       CNContactNonGregorianBirthdayKey as CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault
        var found: [Candidate] = []
        try CNContactStore().enumerateContacts(with: request) { contact, _ in
            guard !imported.contains(contact.identifier),
                  let name = CNContactFormatter.string(from: contact, style: .fullName),
                  let day = day(name: name, birthday: contact.birthday, lunarBirthday: contact.nonGregorianBirthday,
                                today: today),
                  !library.contains(where: { isSameBirthday($0, day) }) else { return }
            found.append(Candidate(id: contact.identifier, day: day))
        }
        return found
    }

    static func importedIDs(defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: importedKey) ?? [])
    }

    static func remember(_ ids: [String], defaults: UserDefaults = .standard) {
        defaults.set(Array(importedIDs(defaults: defaults).union(ids)), forKey: importedKey)
    }

    /// A contact's birthday as a yearly day in 家人. A Chinese-calendar birthday recurs by the lunar
    /// calendar; one without a year starts at its latest occurrence, so it counts no years.
    static func day(name: String, birthday: DateComponents?, lunarBirthday: DateComponents?, today: Date) -> Day? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let lunarDate = lunarBirthday.flatMap { lunarSolarDate($0, today: today) }
        guard let date = lunarDate ?? birthday.flatMap({ gregorianDate($0, today: today) }) else { return nil }
        let family = DayCategory.family.rawValue
        return Day(id: UUID().uuidString,
                   title: String(localized: "\(name)的生日", bundle: AppLocalization.bundle, locale: AppLocalization.locale),
                   date: date, recurring: true, lunar: lunarDate != nil, category: .family,
                   photo: PhotoStyle.defaultCover(forCategoryID: family) ?? .birthday)
    }

    /// Whether `day` is already in the library: the same title on the same date.
    static func isSameBirthday(_ stored: Day, _ day: Day) -> Bool {
        stored.title == day.title && stored.lunar == day.lunar
            && CNDate.calendar.isDate(stored.date, inSameDayAs: day.date)
    }

    private static func gregorianDate(_ birthday: DateComponents, today: Date) -> Date? {
        guard let month = birthday.month, let day = birthday.day else { return nil }
        let calendar = CNDate.calendar
        if let year = birthday.year {
            return calendar.date(from: DateComponents(year: year, month: month, day: day))
        }
        // Without a year, its latest occurrence; February 29 needs a leap year to stay on its day.
        let start = calendar.startOfDay(for: today)
        for year in stride(from: calendar.component(.year, from: start), through: 1900, by: -1) {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
                  calendar.component(.day, from: date) == day, date <= start else { continue }
            return date
        }
        return nil
    }

    /// The Gregorian date of a Chinese-calendar birthday, within the app's 1900–2100 lunar table.
    private static func lunarSolarDate(_ birthday: DateComponents, today: Date) -> Date? {
        guard birthday.calendar?.identifier ?? .chinese == .chinese,
              let month = birthday.month, let day = birthday.day else { return nil }
        let leap = birthday.isLeapMonth ?? false
        if birthday.year != nil {
            var chinese = Calendar(identifier: .chinese)
            chinese.timeZone = CNDate.calendar.timeZone
            var components = birthday
            components.calendar = chinese
            components.timeZone = chinese.timeZone
            guard let instant = chinese.date(from: components) else { return nil }
            let date = CNDate.calendar.startOfDay(for: instant)
            return Lunar.supportedLunarDate(for: date) == nil ? nil : date
        }
        var year = Lunar.solarToLunar(today).year
        var date = Lunar.lunarToSolar(year: year, month: month, day: day, isLeap: leap)
        if date > today {
            year -= 1
            date = Lunar.lunarToSolar(year: year, month: month, day: day, isLeap: leap)
        }
        return Lunar.supportedLunarDate(for: date) == nil ? nil : date
    }
}
