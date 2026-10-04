import Foundation

/// Preview and explicit DEBUG fixtures; never seeded on a normal first launch.
enum SampleData {
    static let days: [Day] = {
        let cal = CNDate.calendar
        func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
            var c = DateComponents()
            c.year = y; c.month = m; c.day = day
            return cal.date(from: c) ?? Date()
        }
        return [
            Day(id: "wedding", title: "结婚纪念日", date: d(2019,10,12),
                recurring: true, category: .love, photo: .wedding,
                note: "那天下了一场小雨，你笑着说是天使撒花。",
                location: "杭州 · 西湖", pinned: true),
            Day(id: "baby", title: "小年糕出生", date: d(2023,2,14),
                recurring: false, category: .family, photo: .baby,
                note: "6斤3两，凌晨3:47。",
                location: "上海 · 第一妇婴", pinned: true),
            Day(id: "birthday", title: "妈妈生日", date: d(1962,6,18),
                recurring: true, lunar: true, category: .family, photo: .birthday,
                note: "今年是 64 岁，要订桂花糖藕。"),
            Day(id: "midautumn", title: "中秋团圆", date: d(2025,10,6),
                recurring: true, lunar: true, category: .family, photo: .home,
                note: "今年回家吃妈妈做的月饼。"),
            Day(id: "japan", title: "北海道旅行", date: d(2026,7,20),
                recurring: false, category: .travel, photo: .japan,
                note: "札幌→小樽→函馆，记得提前订民宿。",
                location: "日本 · 北海道"),
            Day(id: "kaoyan", title: "考研初试", date: d(2026,12,20),
                recurring: false, category: .work, photo: .study,
                note: "今天背了 80 个单词，还差 1200。",
                categoryLabel: "学业"),
            Day(id: "firstmet", title: "与他相遇", date: d(2017,3,8),
                recurring: false, category: .love, photo: .memorial,
                note: "图书馆三楼，靠窗的位置。"),
            Day(id: "work", title: "入职周年", date: d(2021,8,1),
                recurring: true, category: .work, photo: .work),
            Day(id: "dog", title: "领养豆豆", date: d(2020,5,30),
                recurring: false, category: .family, photo: .pet,
                note: "从流浪动物救助站带回家的那天。"),
            Day(id: "moved", title: "搬进新家", date: d(2024,11,5),
                recurring: false, category: .life, photo: .home,
                location: "上海 · 徐汇"),
        ]
    }()
}
