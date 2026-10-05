import XCTest
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
@testable import DaysRemember

@MainActor
final class RenderingTests: XCTestCase {
    func testPhotoDecodeCacheSeparatesContentAndPixelLimits() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 600), format: format)
        func data(_ color: UIColor) throws -> Data {
            try XCTUnwrap(renderer.image { context in
                color.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 900, height: 600))
            }.jpegData(compressionQuality: 0.9))
        }
        let red = try data(.red)
        let blue = try data(.blue)
        let small = try XCTUnwrap(PhotoDecodeCache.decoded(red, maximumPixelSize: 192))
        let repeated = try XCTUnwrap(PhotoDecodeCache.decoded(red, maximumPixelSize: 192))
        let large = try XCTUnwrap(PhotoDecodeCache.decoded(red, maximumPixelSize: 720))
        XCTAssertTrue(small === repeated)
        XCTAssertFalse(small === large)
        XCTAssertEqual(small.cgImage?.width, 192)
        XCTAssertEqual(large.cgImage?.width, 720)
        let other = try XCTUnwrap(PhotoDecodeCache.decoded(blue, maximumPixelSize: 192)?.cgImage)
        XCTAssertGreaterThan(pixel(other, x: 50, y: 50)[2], 240)
        XCTAssertLessThan(pixel(other, x: 50, y: 50)[0], 15)
        XCTAssertNil(PhotoDecodeCache.decoded(Data("corrupt".utf8), maximumPixelSize: 192))
        XCTAssertNil(PhotoDecodeCache.downsample(red, maximumPixelSize: 0))
        XCTAssertNil(PhotoDecodeCache.downsample(red, maximumPixelSize: .nan))
        let cover = try XCTUnwrap(PhotoDecodeCache.bundled("CoverFlowers", maximumPixelSize: 192))
        XCTAssertTrue(cover === PhotoDecodeCache.bundled("CoverFlowers", maximumPixelSize: 192))
    }

    func testDownsamplingAppliesPhotoOrientation() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 600, height: 300), format: format)
            .image { context in
                UIColor.red.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
                UIColor.blue.setFill()
                context.fill(CGRect(x: 300, y: 0, width: 300, height: 300))
            }.cgImage)
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, source, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let image = try XCTUnwrap(PhotoDecodeCache.downsample(data as Data, maximumPixelSize: 300))
        XCTAssertEqual(image.imageOrientation, .up)
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 300)
        XCTAssertEqual(image.size.width / image.size.height,
                       CGFloat(source.height) / CGFloat(source.width), accuracy: 0.02)
        let bitmap = try XCTUnwrap(image.cgImage)
        XCTAssertGreaterThan(pixel(bitmap, x: 75, y: 225)[0], 240)
        XCTAssertGreaterThan(pixel(bitmap, x: 75, y: 75)[2], 240)
    }

    func testPhotoImportPixelBudgetAndBenchmark() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let original = UIGraphicsImageRenderer(size: CGSize(width: 4032, height: 3024), format: format)
            .image { context in
                for x in stride(from: 0, to: 4032, by: 48) {
                    UIColor(hue: CGFloat(x) / 4032, saturation: 0.6, brightness: 0.8, alpha: 1).setFill()
                    context.fill(CGRect(x: x, y: 0, width: 48, height: 3024))
                }
            }
        let input = try XCTUnwrap(original.jpegData(compressionQuality: 0.95))
        // Reference the old import algorithm on the same fixture and simulator scale.
        func legacyImport() -> Data? {
            guard let image = UIImage(data: input) else { return nil }
            let scale = min(1, 1600 / max(image.size.width, image.size.height))
            let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            return UIGraphicsImageRenderer(size: target).image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }.jpegData(compressionQuality: 0.82)
        }
        var timings: [[Double]] = [[], []]
        var outputs = [Data(), Data()]
        for _ in 0..<3 {
            for variant in 0..<2 {
                let start = CFAbsoluteTimeGetCurrent()
                outputs[variant] = try autoreleasepool {
                    try XCTUnwrap(variant == 0 ? legacyImport() : PhotoDecodeCache.compressedJPEG(from: input))
                }
                timings[variant].append((CFAbsoluteTimeGetCurrent() - start) * 1000)
            }
        }
        let legacy = try XCTUnwrap(UIImage(data: outputs[0])?.cgImage)
        let optimized = try XCTUnwrap(UIImage(data: outputs[1])?.cgImage)
        XCTAssertEqual(optimized.width, 1600)
        XCTAssertEqual(optimized.height, 1200)
        XCTAssertNil(PhotoDecodeCache.compressedJPEG(from: Data()))
        let summary = "PHOTO_BENCH legacy_ms=\(timings[0].sorted()[1]) optimized_ms=\(timings[1].sorted()[1]) "
            + "legacy_pixels=\(legacy.width)x\(legacy.height) optimized_pixels=\(optimized.width)x\(optimized.height) "
            + "legacy_bytes=\(outputs[0].count) optimized_bytes=\(outputs[1].count)"
        print(summary)
        let attachment = XCTAttachment(string: summary)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTypographyRespectsDynamicTypeAndLocalLimits() throws {
        let label = Text("31").font(Theme.sans(14, weight: .semibold))
        let normal = try render(label.environment(\.dynamicTypeSize, .large))
        let accessible = try render(label.environment(\.dynamicTypeSize, .accessibility5))
        let capped = try render(label.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .environment(\.dynamicTypeSize, .accessibility5))
        XCTAssertGreaterThan(accessible.height, normal.height)
        XCTAssertLessThan(capped.height, accessible.height)
        XCTAssertGreaterThanOrEqual(capped.height, normal.height)
    }

    func testEveryCoverStaysInsideItsFrame() throws {
        for style in PhotoStyle.allCases {
            XCTAssertNotNil(UIImage(named: style.assetName), "Missing cover: \(style.assetName)")
            let content = VStack(spacing: 0) {
                PhotoTile(style: style, flat: true, cornerRadius: 0).frame(height: 80)
                Color(.sRGB, red: 1, green: 0, blue: 0).frame(height: 20)
            }
            .frame(width: 120)
            let image = try render(content)
            XCTAssertEqual(image.width, 120, style.rawValue)
            XCTAssertEqual(image.height, 100, style.rawValue)
            let bottom = pixel(image, x: 60, y: 5)
            XCTAssertGreaterThan(bottom[0], 240, style.rawValue)
            XCTAssertLessThan(bottom[1], 15, style.rawValue)
        }
    }

    func testDefaultIllustrationsFitWithoutCropping() throws {
        for size in [CGSize(width: 300, height: 120), CGSize(width: 62, height: 72)] {
            for style in [PhotoStyle.systemDefault, .birthday, .japan, .study, .home] {
                let image = try XCTUnwrap(UIImage(named: style.assetName))
                let expected = try render(Image(uiImage: image).resizable().scaledToFit()
                    .frame(width: size.width, height: size.height)
                    .background(Color(hex: 0xF7F8F5)))
                let actual = try render(PhotoTile(style: style, flat: true, cornerRadius: 0)
                    .frame(width: size.width, height: size.height))
                XCTAssertEqual(UIImage(cgImage: actual).pngData(), UIImage(cgImage: expected).pngData(),
                               "\(style.rawValue) at \(size)")
            }
        }
    }

    func testUserPhotoFocusSelectsTheCorrectCrop() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 100, y: 0, width: 100, height: 100))
        }
        for focus in [0.0, 1.0] {
            let content = PhotoTile(style: .home, imageData: source.pngData(), focusX: focus,
                                    flat: true, cornerRadius: 0)
                .frame(width: 100, height: 100)
            let color = pixel(try render(content), x: 50, y: 50)
            XCTAssertGreaterThan(color[focus == 0 ? 0 : 2], 240)
            XCTAssertLessThan(color[focus == 0 ? 2 : 0], 15)
        }
    }

    func testShareTemplatesAndWidgetSizesRender() throws {
        let day = SampleData.days[0]
        for template in ShareCardView.Template.allCases {
            let image = try render(SharePostcard(day: day, info: DayInfo.compute(day), template: template)
                .frame(width: 320))
            XCTAssertEqual(image.width, 320)
            XCTAssertGreaterThan(image.height, 180)
            attach(image, name: "Share-\(template.rawValue)")
        }
        for (size, width, height) in [(DayWidgetCard.Size.small, 164, 164),
                                      (.medium, 344, 164), (.large, 344, 344)] {
            let image = try render(DayWidgetCard(day: day, size: size)
                .frame(width: CGFloat(width), height: CGFloat(height)))
            XCTAssertEqual(image.width, width)
            XCTAssertEqual(image.height, height)
            let accessible = try render(DayWidgetCard(day: day, size: size)
                .frame(width: CGFloat(width), height: CGFloat(height))
                .environment(\.dynamicTypeSize, .accessibility5))
            XCTAssertEqual(UIImage(cgImage: image).pngData(), UIImage(cgImage: accessible).pngData())
            attach(image, name: "Widget-\(width)x\(height)")
        }
    }

    func testShareNotesRequireExplicitOptInForEveryTemplate() throws {
        let day = Day(id: "private-note", title: "纪念日",
                      date: CNDate.calendar.date(from: DateComponents(year: 2020, month: 3, day: 8))!,
                      recurring: true, category: .life, photo: .home,
                      note: "仅供自己阅读的笔记\n不应默认出现在分享图片中")
        let today = CNDate.calendar.date(from: DateComponents(year: 2026, month: 5, day: 9))!
        let info = DayInfo.compute(day, today: today)
        var withoutNote = day
        withoutNote.note = ""

        XCTAssertEqual(ShareCardView.Template.allCases.count, 4)
        for template in ShareCardView.Template.allCases {
            let postcard = SharePostcard(day: day, info: info, template: template)
            XCTAssertFalse(postcard.includeNote)
            let hidden = try render(postcard.frame(width: 320))
            let empty = try render(SharePostcard(day: withoutNote, info: info, template: template)
                .frame(width: 320))
            XCTAssertEqual(UIImage(cgImage: hidden).pngData(), UIImage(cgImage: empty).pngData(),
                           "Hidden notes must not affect \(template.rawValue)")

            let included = try render(SharePostcard(day: day, info: info, template: template, includeNote: true)
                .frame(width: 320))
            XCTAssertEqual(included.width, hidden.width)
            XCTAssertGreaterThan(included.height, hidden.height, template.rawValue)
            XCTAssertNotEqual(UIImage(cgImage: included).pngData(), UIImage(cgImage: hidden).pngData(),
                              template.rawValue)
        }
    }

    func testPolishedDayLayoutsRenderAtCompactAndAccessibleWidths() throws {
        let suite = "PolishedLayoutTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DayStore(defaults: defaults)
        let today = try XCTUnwrap(CNDate.calendar.date(from: DateComponents(year: 2026, month: 4, day: 23)))
        let day = Day(id: "layout-long", title: "Long-term memories from a summer journey together",
                      date: today.addingTimeInterval(-12_000 * 86_400), category: .travel, photo: .japan, pinned: true)
        let upcoming = Day(id: "layout-upcoming", title: "下一个夏天，一起去看从未见过的海岸线",
                           date: today.addingTimeInterval(23 * 86_400), category: .travel, photo: .japan)
        let category = CategoryDefinition(id: "layout-category", name: "Journeys and the people we meet along the way",
                                          icon: "camera", colorToken: .dusty, isSystem: false)
        for width in [272.0, 342.0, 382.0] {
            for size in [DynamicTypeSize.large, .accessibility5] {
                let content = VStack(alignment: .leading, spacing: 24) {
                    UpcomingDayView(day: upcoming)
                    DayRow(day: day)
                    CategoryTile(category: category, coverDay: day, count: 12_345, onEdit: {})
                }
                .environment(store)
                .environment(\.currentDay, today)
                .environment(\.dynamicTypeSize, size)
                .frame(width: width)
                .background(Theme.bg)
                let image = try render(content)
                XCTAssertEqual(image.width, Int(width))
                XCTAssertGreaterThan(image.height, 300)
                attach(image, name: "Polished-layout-\(Int(width))-\(size)")
            }
        }
    }

    private func render<V: View>(_ view: V) throws -> CGImage {
        let renderer = ImageRenderer(content: view.environment(\.dynamicTypeSize, .large))
        renderer.scale = 1
        return try XCTUnwrap(renderer.cgImage)
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8,
                                bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: -x, y: -y, width: image.width, height: image.height))
        return bytes
    }

    private func attach(_ image: CGImage, name: String) {
        let attachment = XCTAttachment(image: UIImage(cgImage: image))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
