import XCTest
import SwiftUI
@testable import DaysRemember

@MainActor
final class RenderingTests: XCTestCase {
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
            attach(image, name: "Widget-\(width)x\(height)")
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
