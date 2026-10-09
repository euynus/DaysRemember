// Renders the promotional video for 时光: 1080 × 1920 (9:16) at 30 fps, H.264, silent, captioned in
// Simplified Chinese. It is drawn from the App Store screenshots (docs/screenshots/zh-Hans) and the
// app's cover illustrations, so regenerating the screenshots keeps it current. scripts/promo-video.sh
// builds and runs it.
//
// Usage: render <repository> <output.mp4> [--sheet <contact-sheet.png>]
//   --sheet also writes one small frame per second on a grid, to check the cut without playing it.
import AppKit
import AVFoundation
import ImageIO

let size = CGSize(width: 1080, height: 1920)
let fps = 30
/// Neighbouring scenes cross-fade over this many seconds.
let overlap = 0.45

// MARK: - Look

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

// The app's tokens (Theme/Tokens.swift) and the product site's.
let paper = NSColor(hex: 0xFCFCFA)
let coverPaper = NSColor(hex: 0xF7F8F5)
let chipFill = NSColor(hex: 0xF0F0EE)
let ink = NSColor(hex: 0x242424)
let ink2 = NSColor(hex: 0x646460)
let muted = NSColor(hex: 0x757570)
let accent = NSColor(hex: 0xBB4235)
let accentSoft = NSColor(hex: 0xF4E3E0)
let hairline = NSColor(hex: 0x15171C, alpha: 0.14)

func font(_ name: String, _ size: CGFloat) -> NSFont {
    guard let font = NSFont(name: name, size: size) else { fatalError("Missing font \(name)") }
    return font
}
func sans(_ size: CGFloat) -> NSFont { font("PingFangSC-Regular", size) }
func sansBold(_ size: CGFloat) -> NSFont { font("PingFangSC-Semibold", size) }
func numeral(_ size: CGFloat) -> NSFont { font("Baskerville", size) }

let grouped: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "zh_CN")
    return formatter
}()

// MARK: - Timing

func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
func progress(_ t: Double, from start: Double, over duration: Double) -> Double { clamp((t - start) / duration) }
func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
/// Overshoots a little before settling, like the site's --spring.
func spring(_ x: Double) -> Double {
    let c1 = 1.70158, c3 = c1 + 1
    return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
}

// MARK: - Canvas

/// A CGContext with its origin at the top left, as the layout below is written.
final class Canvas {
    let context: CGContext

    init(_ context: CGContext, scale: CGFloat = 1) {
        self.context = context
        context.translateBy(x: 0, y: size.height * scale)
        context.scaleBy(x: scale, y: -scale)
        context.interpolationQuality = .high
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    }

    /// Draws `body` as one layer, faded, moved, turned and scaled about `anchor` together.
    func layer(alpha: Double = 1, offset: CGPoint = .zero, scale: Double = 1, rotation: Double = 0,
               anchor: CGPoint = CGPoint(x: size.width / 2, y: size.height / 2), _ body: () -> Void) {
        guard alpha > 0.002 else { return }
        context.saveGState()
        context.translateBy(x: anchor.x + offset.x, y: anchor.y + offset.y)
        context.rotate(by: rotation * .pi / 180)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -anchor.x, y: -anchor.y)
        if alpha < 0.998 {
            context.setAlpha(alpha)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            body()
            context.endTransparencyLayer()
        } else {
            body()
        }
        context.restoreGState()
    }

    func fill(_ rect: CGRect, _ color: NSColor, radius: CGFloat = 0) {
        context.setFillColor(color.cgColor)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.fillPath()
    }

    func stroke(_ rect: CGRect, _ color: NSColor, radius: CGFloat, width: CGFloat = 2) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        let inset = rect.insetBy(dx: width / 2, dy: width / 2)
        context.addPath(CGPath(roundedRect: inset, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.strokePath()
    }

    func clip(_ rect: CGRect, radius: CGFloat) {
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()
    }

    func draw(_ image: CGImage, in rect: CGRect) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    func attributed(_ string: String, _ font: NSFont, _ color: NSColor, align: NSTextAlignment = .center,
                    kern: CGFloat = 0, lineHeight: CGFloat? = nil) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = align
        if let lineHeight {
            style.minimumLineHeight = lineHeight
            style.maximumLineHeight = lineHeight
        }
        return NSAttributedString(string: string, attributes: [
            .font: font, .foregroundColor: color, .kern: kern, .paragraphStyle: style,
        ])
    }

    func measure(_ text: NSAttributedString, width: CGFloat = size.width) -> CGSize {
        let bounds = text.boundingRect(with: CGSize(width: width, height: 4000),
                                       options: [.usesLineFragmentOrigin, .usesFontLeading])
        return CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
    }

    /// Draws text with its top edge at `y`, laid out within `x ..< x + width`.
    func text(_ text: NSAttributedString, x: CGFloat = 60, y: CGFloat, width: CGFloat = size.width - 120) {
        let height = measure(text, width: width).height
        text.draw(with: CGRect(x: x, y: y, width: width, height: height),
                  options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}

// MARK: - Pieces

struct Assets {
    let home, calendar, widgets, share: CGImage
    let icon: CGImage
    let covers: [String: CGImage]

    init(repository: String) {
        func load(_ path: String) -> CGImage {
            let url = URL(fileURLWithPath: repository).appendingPathComponent(path)
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Cannot read \(path)") }
            return image
        }
        let shots = "docs/screenshots/zh-Hans/"
        home = load(shots + "01-home.jpg")
        calendar = load(shots + "03-calendar.jpg")
        widgets = load(shots + "04-widgets.jpg")
        share = load(shots + "05-share.jpg")
        icon = load("DaysRemember/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
        var covers: [String: CGImage] = [:]
        for name in ["Celebration", "Flowers", "Voyage", "Garden", "Homecoming", "Journal"] {
            covers[name] = load("DaysRemember/Resources/Assets.xcassets/Cover\(name).imageset/cover.png")
        }
        self.covers = covers
    }
}

/// The app icon, `side` points square, centred on `center`.
func icon(_ assets: Assets, center: CGPoint, side: CGFloat, on canvas: Canvas) {
    let rect = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    let radius = side * 0.2237
    canvas.context.saveGState()
    canvas.context.setShadow(offset: CGSize(width: 0, height: -16), blur: 48, color: NSColor(white: 0, alpha: 0.14).cgColor)
    canvas.fill(rect, ink, radius: radius)
    canvas.context.restoreGState()
    canvas.context.saveGState()
    canvas.clip(rect, radius: radius)
    canvas.draw(assets.icon, in: rect)
    canvas.context.restoreGState()
}

/// A cover illustration on its paper, like a sticker on a journal page.
func coverTile(_ image: CGImage, center: CGPoint, side: CGFloat, on canvas: Canvas) {
    let rect = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    canvas.context.saveGState()
    canvas.context.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: NSColor(white: 0, alpha: 0.08).cgColor)
    canvas.fill(rect, coverPaper, radius: side * 0.08)
    canvas.context.restoreGState()
    canvas.context.saveGState()
    canvas.clip(rect, radius: side * 0.08)
    canvas.draw(image, in: rect.insetBy(dx: side * 0.04, dy: side * 0.04))
    canvas.context.restoreGState()
    canvas.stroke(rect, hairline, radius: side * 0.08, width: 1.5)
}

/// A screenshot in a phone-shaped frame, `width` wide with its top at `top`. `zoom` enlarges the
/// screen inside the frame about `focus` (a point in the screen, from 0 to 1 on each axis).
func phone(_ screen: CGImage, top: CGFloat, width: CGFloat, zoom: Double = 1,
           focus: CGPoint = CGPoint(x: 0.5, y: 0.5), on canvas: Canvas) {
    let height = width * CGFloat(screen.height) / CGFloat(screen.width)
    let frame = CGRect(x: (size.width - width) / 2, y: top, width: width, height: height)
    let radius = width * 0.125
    canvas.context.saveGState()
    canvas.context.setShadow(offset: CGSize(width: 0, height: -30), blur: 90, color: NSColor(white: 0, alpha: 0.12).cgColor)
    canvas.fill(frame, paper, radius: radius)
    canvas.context.restoreGState()

    canvas.context.saveGState()
    canvas.clip(frame, radius: radius)
    let z = CGFloat(zoom)
    let fx = frame.minX + frame.width * focus.x, fy = frame.minY + frame.height * focus.y
    canvas.draw(screen, in: CGRect(x: fx - (fx - frame.minX) * z, y: fy - (fy - frame.minY) * z,
                                   width: frame.width * z, height: frame.height * z))
    canvas.context.restoreGState()
    canvas.stroke(frame, hairline, radius: radius)
}

/// The vermilion label and the headline above each feature, rising in one after the other.
func caption(_ eyebrow: String, _ title: String, t: Double, on canvas: Canvas) {
    let e = easeOut(progress(t, from: 0.1, over: 0.7))
    let h = easeOut(progress(t, from: 0.22, over: 0.7))
    canvas.layer(alpha: e, offset: CGPoint(x: 0, y: 24 * (1 - e))) {
        canvas.text(canvas.attributed(eyebrow, sansBold(34), accent, kern: 6), y: 150)
    }
    canvas.layer(alpha: h, offset: CGPoint(x: 0, y: 30 * (1 - h))) {
        canvas.text(canvas.attributed(title, sansBold(68), ink), y: 212)
    }
}

/// A feature shown on the phone: the caption, then the phone rising in while the camera moves in.
func phoneScene(_ eyebrow: String, _ title: String, screen: CGImage, duration: Double,
                zoom: ClosedRange<Double>, focus: CGPoint) -> Scene {
    Scene(duration: duration) { t, canvas in
        caption(eyebrow, title, t: t, on: canvas)
        let rise = easeOut(progress(t, from: 0.25, over: 0.9))
        let move = easeInOut(progress(t, from: 0.9, over: duration - 0.9))
        canvas.layer(alpha: rise, offset: CGPoint(x: 0, y: 140 * (1 - rise))) {
            phone(screen, top: 400, width: 640, zoom: zoom.lowerBound + (zoom.upperBound - zoom.lowerBound) * move,
                  focus: focus, on: canvas)
        }
    }
}

// MARK: - Scenes

struct Scene {
    let duration: Double
    let draw: (Double, Canvas) -> Void
}

func scenes(_ assets: Assets) -> [Scene] {
    // Title: the covers land around the icon like stickers, then drift.
    let stickers: [(name: String, x: CGFloat, y: CGFloat, side: CGFloat, angle: Double, delay: Double)] = [
        ("Celebration", 250, 330, 300, -7, 0.0),
        ("Flowers", 840, 300, 270, 6, 0.12),
        ("Homecoming", 135, 960, 210, -5, 0.24),
        ("Journal", 948, 1010, 210, 7, 0.36),
        ("Voyage", 210, 1560, 290, 5, 0.48),
        ("Garden", 860, 1600, 300, -6, 0.6),
    ]
    let title = Scene(duration: 3.6) { t, canvas in
        for (index, sticker) in stickers.enumerated() {
            let p = progress(t, from: sticker.delay, over: 0.8)
            let drift = CGFloat(sin((t + Double(index)) * 1.3)) * 6
            canvas.layer(alpha: clamp(p / 0.35), offset: CGPoint(x: 0, y: drift),
                         scale: 0.8 + 0.2 * spring(p), rotation: sticker.angle - 8 * (1 - spring(p)),
                         anchor: CGPoint(x: sticker.x, y: sticker.y)) {
                coverTile(assets.covers[sticker.name]!, center: CGPoint(x: sticker.x, y: sticker.y),
                          side: sticker.side, on: canvas)
            }
        }
        let pop = progress(t, from: 0.45, over: 0.8)
        canvas.layer(alpha: clamp(pop / 0.3), scale: 0.6 + 0.4 * spring(pop), anchor: CGPoint(x: 540, y: 700)) {
            icon(assets, center: CGPoint(x: 540, y: 700), side: 220, on: canvas)
        }
        let name = easeOut(progress(t, from: 0.75, over: 0.8))
        canvas.layer(alpha: name, offset: CGPoint(x: 0, y: 36 * (1 - name))) {
            canvas.text(canvas.attributed("时光", sansBold(150), ink, kern: 8), y: 840)
        }
        let line = easeOut(progress(t, from: 1.0, over: 0.8))
        canvas.layer(alpha: line, offset: CGPoint(x: 0, y: 30 * (1 - line))) {
            canvas.text(canvas.attributed("温柔记住每一个重要的日子", sans(48), ink2, kern: 2), y: 1070)
        }
    }

    // The countdown, set like the app's day detail: it counts up to the days left.
    let countdown = Scene(duration: 4.6) { t, canvas in
        caption("倒数", "离那一天，还有多少天", t: t, on: canvas)
        let card = easeOut(progress(t, from: 0.25, over: 0.9))
        let count = easeOut(progress(t, from: 0.7, over: 1.6))
        canvas.layer(alpha: card, offset: CGPoint(x: 0, y: 100 * (1 - card))) {
            let cover = CGRect(x: 90, y: 400, width: 900, height: 560)
            canvas.fill(cover, coverPaper)
            canvas.context.saveGState()
            canvas.clip(cover, radius: 0)
            let flowers = assets.covers["Flowers"]!
            canvas.draw(flowers, in: CGRect(x: cover.midX - 290, y: cover.midY - 290, width: 580, height: 580))
            canvas.context.restoreGState()

            canvas.text(canvas.attributed("结婚纪念日", sansBold(76), ink, align: .left), x: 90, y: 1010, width: 900)
            canvas.text(canvas.attributed("下一次 · 第7周年 · 2026年10月12日", sans(36), ink2, align: .left),
                        x: 90, y: 1118, width: 900)
            let days = canvas.attributed(grouped.string(from: NSNumber(value: Int((172 * count).rounded())))!,
                                         numeral(330), accent, align: .left)
            canvas.text(days, x: 74, y: 1150, width: 900)
            let daysWidth = canvas.measure(days).width
            canvas.text(canvas.attributed("天后", sans(44), ink2, align: .left), x: 74 + daysWidth + 20, y: 1420, width: 300)
            let elapsed = grouped.string(from: NSNumber(value: Int((2385 * count).rounded())))!
            canvas.text(canvas.attributed("已过 \(elapsed) 天", sans(40), ink2, align: .left), x: 90, y: 1560, width: 900)
            canvas.fill(CGRect(x: 90, y: 1650, width: 900, height: 2), hairline)
            canvas.text(canvas.attributed("记忆", sansBold(32), accent, align: .left), x: 90, y: 1690, width: 900)
            canvas.text(canvas.attributed("那天下了一场小雨，你笑着说是天使撒花。", sans(40), ink, align: .left),
                        x: 90, y: 1745, width: 900)
        }
    }

    // Privacy: a zero, and what it means.
    let chips = ["无需账号", "无广告", "无追踪", "无第三方 SDK"]
    let privacy = Scene(duration: 3.6) { t, canvas in
        let zero = progress(t, from: 0.1, over: 0.9)
        canvas.layer(alpha: clamp(zero / 0.3), scale: 0.6 + 0.4 * spring(zero), anchor: CGPoint(x: 540, y: 680)) {
            canvas.text(canvas.attributed("0", numeral(560), accent), y: 330)
        }
        let head = easeOut(progress(t, from: 0.45, over: 0.8))
        canvas.layer(alpha: head, offset: CGPoint(x: 0, y: 30 * (1 - head))) {
            canvas.text(canvas.attributed("不收集任何数据", sansBold(76), ink), y: 1030)
            canvas.text(canvas.attributed("日子、照片和设置只保存在\n你的设备和你自己的 iCloud 中", sans(42), ink2, lineHeight: 66),
                        y: 1150)
        }
        let labels = chips.map { canvas.attributed($0, sans(36), ink) }
        let widths = labels.map { canvas.measure($0).width + 56 }
        var x = (size.width - widths.reduce(0, +) - CGFloat(chips.count - 1) * 18) / 2
        for (index, label) in labels.enumerated() {
            let p = progress(t, from: 0.9 + Double(index) * 0.12, over: 0.7)
            let rect = CGRect(x: x, y: 1340, width: widths[index], height: 76)
            canvas.layer(alpha: clamp(p / 0.3), scale: 0.7 + 0.3 * spring(p), anchor: CGPoint(x: rect.midX, y: rect.midY)) {
                canvas.fill(rect, chipFill, radius: 38)
                canvas.text(label, x: rect.minX, y: rect.minY + 12, width: rect.width)
            }
            x += widths[index] + 18
        }
    }

    // The end card: the name, then where to find it.
    let end = Scene(duration: 3.8) { t, canvas in
        let pop = progress(t, from: 0.1, over: 0.8)
        canvas.layer(alpha: clamp(pop / 0.3), scale: 0.6 + 0.4 * spring(pop), anchor: CGPoint(x: 540, y: 640)) {
            icon(assets, center: CGPoint(x: 540, y: 640), side: 240, on: canvas)
        }
        let name = easeOut(progress(t, from: 0.35, over: 0.8))
        canvas.layer(alpha: name, offset: CGPoint(x: 0, y: 30 * (1 - name))) {
            canvas.text(canvas.attributed("时光", sansBold(132), ink, kern: 8), y: 800)
            canvas.text(canvas.attributed("温柔记住每一个重要的日子", sans(46), ink2, kern: 2), y: 1000)
        }
        let soon = easeOut(progress(t, from: 0.7, over: 0.8))
        canvas.layer(alpha: soon, offset: CGPoint(x: 0, y: 24 * (1 - soon))) {
            let label = canvas.attributed("即将登陆 App Store", sansBold(42), accent)
            let width = canvas.measure(label).width + 96
            let pill = CGRect(x: (size.width - width) / 2, y: 1150, width: width, height: 104)
            canvas.fill(pill, accentSoft, radius: 52)
            canvas.text(label, x: pill.minX, y: pill.minY + 22, width: pill.width)
            canvas.text(canvas.attributed("days.gooday.dev", sans(40), muted, kern: 1), y: 1310)
        }
    }

    return [
        title,
        phoneScene("纪念日与倒数", "重要的日子，都放在这里", screen: assets.home, duration: 4.2,
                   zoom: 1.0...1.14, focus: CGPoint(x: 0.5, y: 0.3)),
        countdown,
        phoneScene("农历与节气", "农历生日，也不会忘", screen: assets.calendar, duration: 4.0,
                   zoom: 1.0...1.32, focus: CGPoint(x: 0.5, y: 0.34)),
        phoneScene("小组件", "放在主屏幕，抬头就看见", screen: assets.widgets, duration: 3.8,
                   zoom: 1.0...1.18, focus: CGPoint(x: 0.5, y: 0.48)),
        phoneScene("分享卡片", "做成卡片，分享给重要的人", screen: assets.share, duration: 3.8,
                   zoom: 1.0...1.26, focus: CGPoint(x: 0.5, y: 0.62)),
        privacy,
        end,
    ]
}

// MARK: - Film

struct Film {
    let scenes: [Scene]
    let starts: [Double]
    let duration: Double

    init(_ scenes: [Scene]) {
        self.scenes = scenes
        var starts: [Double] = []
        var time = 0.0
        for scene in scenes {
            starts.append(time)
            time += scene.duration - overlap
        }
        self.starts = starts
        duration = time + overlap
    }

    /// Draws the frame at `t` seconds; neighbouring scenes cross-fade where they overlap.
    func draw(at t: Double, on canvas: Canvas) {
        canvas.fill(CGRect(origin: .zero, size: size), paper)
        for (index, scene) in scenes.enumerated() {
            let local = t - starts[index]
            guard local >= 0, local <= scene.duration else { continue }
            let fadeIn = index == 0 ? 1 : easeInOut(clamp(local / overlap))
            let fadeOut = index == scenes.count - 1 ? 1 : easeInOut(clamp((scene.duration - local) / overlap))
            canvas.layer(alpha: min(fadeIn, fadeOut)) { scene.draw(local, canvas) }
        }
    }
}

func writeVideo(_ film: Film, to output: URL) throws {
    try? FileManager.default.removeItem(at: output)
    let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: Int(size.width),
        AVVideoHeightKey: Int(size.height),
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 12_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoExpectedSourceFrameRateKey: fps,
            AVVideoMaxKeyFrameIntervalKey: fps * 2,
        ],
    ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: Int(size.width),
        kCVPixelBufferHeightKey as String: Int(size.height),
    ])
    writer.add(input)
    guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
    writer.startSession(atSourceTime: .zero)

    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let frames = Int((film.duration * Double(fps)).rounded())
    for frame in 0..<frames {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
        guard let buffer else { throw CocoaError(.fileWriteOutOfSpace) }
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width), height: Int(size.height),
                                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        autoreleasepool { film.draw(at: Double(frame) / Double(fps), on: Canvas(context)) }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps))) else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
    }
    input.markAsFinished()
    let finished = DispatchSemaphore(value: 0)
    writer.finishWriting { finished.signal() }
    finished.wait()
    if writer.status != .completed { throw writer.error ?? CocoaError(.fileWriteUnknown) }
}

/// One frame per second at a fifth of the size, six to a row.
func writeContactSheet(_ film: Film, to output: URL) throws {
    let scale: CGFloat = 0.2, columns = 6
    let times = Array(stride(from: 0.5, to: film.duration, by: 1.0))
    let cell = CGSize(width: size.width * scale, height: size.height * scale)
    let rows = (times.count + columns - 1) / columns
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let sheet = CGContext(data: nil, width: Int(cell.width) * columns, height: Int(cell.height) * rows,
                          bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    for (index, t) in times.enumerated() {
        let frame = CGContext(data: nil, width: Int(cell.width), height: Int(cell.height), bitsPerComponent: 8,
                              bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        autoreleasepool { film.draw(at: t, on: Canvas(frame, scale: scale)) }
        let column = index % columns, row = index / columns
        sheet.draw(frame.makeImage()!, in: CGRect(x: CGFloat(column) * cell.width,
                                                   y: CGFloat(rows - 1 - row) * cell.height,
                                                   width: cell.width, height: cell.height))
    }
    guard let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, sheet.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

// MARK: - Main

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write("usage: render <repository> <output.mp4> [--sheet <contact-sheet.png>]\n".data(using: .utf8)!)
    exit(2)
}
let film = Film(scenes(Assets(repository: arguments[1])))
if let flag = arguments.firstIndex(of: "--sheet"), flag + 1 < arguments.count {
    try writeContactSheet(film, to: URL(fileURLWithPath: arguments[flag + 1]))
}
try writeVideo(film, to: URL(fileURLWithPath: arguments[2]))
print(String(format: "%@: %.1f s, %d frames", arguments[2], film.duration, Int((film.duration * Double(fps)).rounded())))
