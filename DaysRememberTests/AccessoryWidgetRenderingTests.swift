import XCTest
import SwiftUI
import UIKit
@testable import DaysRemember

@MainActor
final class AccessoryWidgetRenderingTests: XCTestCase {
    private let today = CNDate.calendar.date(from: DateComponents(year: 2026, month: 10, day: 4))!
    private let layouts: [(style: DayAccessoryWidget.Style, size: CGSize)] = [
        (.circular, CGSize(width: 72, height: 72)),
        (.rectangular, CGSize(width: 160, height: 72)),
        (.inline, CGSize(width: 230, height: 20))
    ]

    func testTodayPastAndFutureRenderAtExactBoundsInEveryStyle() throws {
        for (style, size) in layouts {
            var images = Set<Data>()
            for (name, offset) in [("Today", 0), ("Past", -31), ("Future", 31)] {
                let day = try makeDay(offset: offset)
                let widget = DayAccessoryWidget(day: day, style: style, today: today)
                let image = try render(widget, size: size)
                try assertVisible(image, size: size)
                images.insert(Data(try pixels(image)))
                let accessible = try render(widget, size: size, textSize: .accessibility5)
                XCTAssertEqual(try pixels(image), try pixels(accessible), "\(style)-\(name) text-size cap")
                attach(image, name: "Accessory-\(style)-\(name)")
            }
            XCTAssertEqual(images.count, 3, "\(style) must distinguish today, past, and future")
        }
    }

    func testEmptyDeletedAndNoUpcomingStatesAreDistinct() throws {
        for (style, size) in layouts {
            var images = Set<Data>()
            for (name, missing, hasDays, expected) in [
                ("Empty", false, false, "还没有日子"),
                ("NoUpcoming", false, true, "暂无即将到来的日子"),
                ("Deleted", true, true, "日子已删除")
            ] {
                let widget = DayAccessoryWidget(day: nil, style: style, today: today,
                                                selectionMissing: missing, hasAnyDays: hasDays)
                XCTAssertEqual(widget.accessibilitySummary, expected)
                let image = try render(widget, size: size)
                try assertVisible(image, size: size)
                images.insert(Data(try pixels(image)))
                let accessible = try render(widget, size: size, textSize: .accessibility5)
                XCTAssertEqual(try pixels(image), try pixels(accessible))
                attach(image, name: "Accessory-\(style)-\(name)")
            }
            XCTAssertEqual(images.count, 3, "\(style) must distinguish all empty states")
            let deletedLastDay = DayAccessoryWidget(day: nil, style: style, today: today,
                                                    selectionMissing: true)
            XCTAssertEqual(deletedLastDay.accessibilitySummary, "日子已删除")
            let deletedWithOtherDays = DayAccessoryWidget(day: nil, style: style, today: today,
                                                          selectionMissing: true, hasAnyDays: true)
            XCTAssertEqual(try pixels(render(deletedLastDay, size: size)),
                           try pixels(render(deletedWithOtherDays, size: size)))
        }
    }

    func testLongTitlesAndLargeCountsFitWithoutOverflow() throws {
        let titles = [String(repeating: "一起走过的每一个值得纪念的日子", count: 8),
                      String(repeating: "AnUnbrokenAnniversaryTitle", count: 8)]
        for (style, size) in layouts {
            for (index, title) in titles.enumerated() {
                for offset in [-123456, 123456] {
                    let day = try makeDay(offset: offset, title: title)
                    XCTAssertEqual(DayInfo.compute(day, today: today).days, abs(offset))
                    let widget = DayAccessoryWidget(day: day, style: style, today: today)
                    let image = try render(widget, size: size)
                    try assertVisible(image, size: size)
                    let padded = try render(widget, size: size, padding: 6, textSize: .accessibility5)
                    try assertClearPadding(padded, contentSize: size, inset: 6)
                    XCTAssertTrue(widget.accessibilitySummary.hasPrefix(title))
                    XCTAssertTrue(widget.accessibilitySummary.contains("123456\(offset < 0 ? "天前" : "天后")"))
                    attach(image, name: "Accessory-\(style)-LongTitle\(index)-\(offset)")
                }
            }
        }
    }

    func testRectangularLayoutDropsDateWhenHeightIsLimited() throws {
        let day = try makeDay(offset: 31)
        let widget = DayAccessoryWidget(day: day, style: .rectangular, today: today)
        let compactSize = CGSize(width: 160, height: 44)
        let image = try render(widget, size: compactSize)
        try assertVisible(image, size: compactSize)
        let padded = try render(widget, size: compactSize, padding: 6)
        try assertClearPadding(padded, contentSize: compactSize, inset: 6)
        XCTAssertTrue(widget.accessibilitySummary.contains(CNDate.full(day.date)))
        attach(image, name: "Accessory-rectangular-Compact")
    }

    func testCompactCircularAndRectangularBoundsKeepCountdownVisible() throws {
        for (style, size) in [(DayAccessoryWidget.Style.circular, CGSize(width: 56, height: 56)),
                              (.rectangular, CGSize(width: 160, height: 56))] {
            for offset in [0, 8, -123456] {
                let day = try makeDay(offset: offset, title: "一个很长的重要日子名称")
                let widget = DayAccessoryWidget(day: day, style: style, today: today)
                let image = try render(widget, size: size)
                try assertVisible(image, size: size)
                let padded = try render(widget, size: size, padding: 6, textSize: .accessibility5)
                try assertClearPadding(padded, contentSize: size, inset: 6)
                attach(image, name: "Accessory-\(style)-56pt-\(offset)")
            }
        }
    }

    func testAccessibilityKeepsFullTitleDirectionAndComputedOccurrence() throws {
        for (offset, expected) in [(0, "就是今天"), (-31, "31天前"), (31, "31天后")] {
            let day = try makeDay(offset: offset)
            for (style, _) in layouts {
                let widget = DayAccessoryWidget(day: day, style: style, today: today)
                XCTAssertEqual(widget.accessibilitySummary, "\(day.title)，\(expected)，\(CNDate.full(day.date))")
            }
        }
        var recurring = try makeDay(offset: -365)
        recurring.date = try XCTUnwrap(CNDate.calendar.date(from: DateComponents(year: 2020, month: 10, day: 5)))
        recurring.recurring = true
        for (style, size) in layouts {
            let widget = DayAccessoryWidget(day: recurring, style: style, today: today,
                                            selectionMissing: true, hasAnyDays: true)
            XCTAssertEqual(widget.accessibilitySummary, "重要日子，1天后，2026年10月5日")
            var occurrence = recurring
            occurrence.recurring = false
            occurrence.date = DayInfo.compute(recurring, today: today).displayDate
            let expected = DayAccessoryWidget(day: occurrence, style: style, today: today)
            XCTAssertEqual(try pixels(render(widget, size: size)), try pixels(render(expected, size: size)),
                           "\(style) must render the computed occurrence, not the original date")
        }
    }

    func testPhotosAndNotesNeverAffectLockScreenContent() throws {
        let day = try makeDay(offset: 31)
        var privateDay = day
        privateDay.note = "仅供自己阅读的笔记，不应出现在锁屏上"
        privateDay.photo = .birthday
        let photo = ImageRenderer(content: Color.red.frame(width: 8, height: 8))
        photo.scale = 1
        privateDay.photoData = try XCTUnwrap(photo.uiImage?.pngData())
        for (style, size) in layouts {
            let original = DayAccessoryWidget(day: day, style: style, today: today)
            let withPrivateContent = DayAccessoryWidget(day: privateDay, style: style, today: today)
            XCTAssertEqual(original.accessibilitySummary, withPrivateContent.accessibilitySummary)
            XCTAssertEqual(try pixels(render(original, size: size)),
                           try pixels(render(withPrivateContent, size: size)), "\(style) leaked private content")
        }
    }

    func testSystemPrimaryTextRendersInLightAndDarkAppearance() throws {
        let day = try makeDay(offset: 31)
        for (style, size) in layouts {
            let widget = DayAccessoryWidget(day: day, style: style, today: today)
            let light = try render(widget, size: size)
            let dark = try render(widget, size: size, colorScheme: .dark)
            try assertVisible(light, size: size)
            try assertVisible(dark, size: size)
            XCTAssertNotEqual(try pixels(light), try pixels(dark), "\(style) should follow system appearance")
            attach(dark, name: "Accessory-\(style)-Dark")
        }
    }

    private func makeDay(offset: Int, title: String = "重要日子") throws -> Day {
        let date = try XCTUnwrap(CNDate.calendar.date(byAdding: .day, value: offset, to: today))
        return Day(id: "accessory-\(offset)", title: title, date: date, category: .life, photo: .home)
    }

    private func render(_ widget: DayAccessoryWidget, size: CGSize, padding: CGFloat = 0,
                        textSize: DynamicTypeSize = .large, colorScheme: ColorScheme = .light) throws -> CGImage {
        // App rendering leaves the native accessory background empty, so alpha checks inspect the content.
        let renderer = ImageRenderer(content: widget
            .frame(width: size.width, height: size.height)
            .padding(padding)
            .environment(\.dynamicTypeSize, textSize)
            .environment(\.colorScheme, colorScheme))
        renderer.scale = 1
        renderer.isOpaque = false
        return try XCTUnwrap(renderer.cgImage)
    }

    private func assertVisible(_ image: CGImage, size: CGSize,
                               file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(image.width, Int(size.width), file: file, line: line)
        XCTAssertEqual(image.height, Int(size.height), file: file, line: line)
        let bytes = try pixels(image)
        let visible = stride(from: 3, to: bytes.count, by: 4).filter { bytes[$0] > 0 }.count
        XCTAssertGreaterThan(visible, 30, "Expected nonblank alpha", file: file, line: line)
        XCTAssertLessThan(visible, image.width * image.height, "Expected transparent space", file: file, line: line)
    }

    private func assertClearPadding(_ image: CGImage, contentSize: CGSize, inset: Int,
                                    file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(image.width, Int(contentSize.width) + inset * 2, file: file, line: line)
        XCTAssertEqual(image.height, Int(contentSize.height) + inset * 2, file: file, line: line)
        let bytes = try pixels(image)
        for y in 0..<image.height {
            for x in 0..<image.width where x < inset || x >= image.width - inset
                || y < inset || y >= image.height - inset {
                if bytes[(y * image.width + x) * 4 + 3] != 0 {
                    XCTFail("Content overflowed its bounds at (\(x), \(y))", file: file, line: line)
                    return
                }
            }
        }
    }

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                                 bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                                 space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
                                                    | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

    private func attach(_ image: CGImage, name: String) {
        let attachment = XCTAttachment(image: UIImage(cgImage: image))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
