// Renders the promotional video for 时光: 1080 × 1920 (9:16) at 30 fps, H.264, silent, captioned in
// Simplified Chinese, in the app's 柔彩便当 look. It is drawn from the App Store screenshots
// (docs/screenshots/zh-Hans) and the flat cover illustrations (docs/assets/covers), so regenerating the
// screenshots keeps it current. scripts/promo-video.sh builds and runs it.
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

// The app's tokens (Theme/Tokens.swift) and the product site's (docs/assets/site.css).
let paper = NSColor(hex: 0xF6F6F3)
let paper2 = NSColor(hex: 0xEFEEEA)
let card = NSColor(hex: 0xFFFFFF)
let ink = NSColor(hex: 0x24222B)
let ink2 = NSColor(hex: 0x5E5A66)
let muted = NSColor(hex: 0x6E6A75)
let shadow = NSColor(hex: 0x24222B, alpha: 0.1)

/// A category pastel and the colour of the text and marks drawn on it.
struct Tint {
    let soft, ink: NSColor
    init(_ soft: UInt32, _ ink: UInt32) {
        self.soft = NSColor(hex: soft)
        self.ink = NSColor(hex: ink)
    }
}
let rose = Tint(0xFBE0E8, 0x9C2F55)      // 爱情
let apricot = Tint(0xFCE5CB, 0x8A4B12)   // 家人
let sky = Tint(0xDDEBFA, 0x23608F)       // 旅行
let mint = Tint(0xD7EFE0, 0x2F6A47)      // 工作
let lemon = Tint(0xFBF0C4, 0x7A5A0E)     // 生活
let lavender = Tint(0xE8E4F8, 0x4B3F8F)  // count-up days and memories

func font(_ name: String, _ size: CGFloat) -> NSFont {
    guard let font = NSFont(name: name, size: size) else { fatalError("Missing font \(name)") }
    return font
}
func sans(_ size: CGFloat) -> NSFont { font("PingFangSC-Regular", size) }
func sansBold(_ size: CGFloat) -> NSFont { font("PingFangSC-Semibold", size) }
/// The app's countdown numerals: heavy SF Rounded.
func numeral(_ size: CGFloat) -> NSFont {
    let heavy = NSFont.systemFont(ofSize: size, weight: .heavy)
    guard let rounded = heavy.fontDescriptor.withDesign(.rounded),
          let font = NSFont(descriptor: rounded, size: size) else { fatalError("Missing SF Rounded") }
    return font
}

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

    /// Fills `rect` with a soft drop shadow beneath it, like the site's --shadow.
    func raised(_ rect: CGRect, _ color: NSColor, radius: CGFloat, lift: CGFloat = 10, blur: CGFloat = 30) {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -lift), blur: blur, color: shadow.cgColor)
        fill(rect, color, radius: radius)
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
    let home, past, calendar, widgets, share: CGImage
    let icon: CGImage
    /// The flat covers by file name, rasterized once at `coverPixels` square.
    let covers: [String: CGImage]
    static let coverPixels = 1024

    init(repository: String) {
        let root = URL(fileURLWithPath: repository)
        func load(_ path: String) -> CGImage {
            guard let source = CGImageSourceCreateWithURL(root.appendingPathComponent(path) as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Cannot read \(path)") }
            return image
        }
        /// The SVGs that scripts/flat-covers.py writes for the site and the asset catalogs.
        func cover(_ name: String) -> CGImage {
            let path = "docs/assets/covers/\(name).svg"
            guard let svg = NSImage(contentsOf: root.appendingPathComponent(path)) else { fatalError("Cannot read \(path)") }
            let side = Assets.coverPixels
            let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            svg.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
            NSGraphicsContext.restoreGraphicsState()
            return context.makeImage()!
        }
        let shots = "docs/screenshots/zh-Hans/"
        home = load(shots + "01-home.jpg")
        calendar = load(shots + "03-calendar.jpg")
        widgets = load(shots + "04-widgets.jpg")
        share = load(shots + "05-share.jpg")
        past = load(shots + "07-past.jpg")
        icon = load("DaysRemember/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
        var covers: [String: CGImage] = [:]
        for name in ["flowers", "celebration", "coast", "journal", "everyday", "companionship"] {
            covers[name] = cover(name)
        }
        self.covers = covers
    }
}

/// The app icon, `side` points square, centred on `center`.
func icon(_ assets: Assets, center: CGPoint, side: CGFloat, on canvas: Canvas) {
    let rect = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    let radius = side * 0.2237
    canvas.raised(rect, ink, radius: radius, lift: 12, blur: 40)
    canvas.context.saveGState()
    canvas.clip(rect, radius: radius)
    canvas.draw(assets.icon, in: rect)
    canvas.context.restoreGState()
}

/// A flat cover drawn straight onto its category pastel, like the cards in the app.
func coverTile(_ image: CGImage, tint: Tint, center: CGPoint, side: CGFloat, on canvas: Canvas) {
    let rect = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    canvas.raised(rect, tint.soft, radius: side * 0.2)
    canvas.draw(image, in: rect.insetBy(dx: side * 0.14, dy: side * 0.14))
}

/// A rounded label in a pastel with its top at `y`, starting at `x` or centred when `x` is nil.
func chip(_ label: String, fill: NSColor, color: NSColor, size fontSize: CGFloat, x: CGFloat? = nil, y: CGFloat,
          on canvas: Canvas) {
    let text = canvas.attributed(label, sansBold(fontSize), color)
    let measured = canvas.measure(text)
    let height = (fontSize * 2).rounded()
    let width = measured.width + fontSize * 1.4
    let rect = CGRect(x: x ?? (size.width - width) / 2, y: y, width: width, height: height)
    canvas.fill(rect, fill, radius: height / 2)
    canvas.text(text, x: rect.minX, y: rect.minY + (height - measured.height) / 2, width: rect.width)
}

/// A screenshot in a white phone-shaped frame, `width` wide with its top at `top`. `zoom` enlarges the
/// screen inside the frame about `focus` (a point in the screen, from 0 to 1 on each axis).
func phone(_ screen: CGImage, top: CGFloat, width: CGFloat, zoom: Double = 1,
           focus: CGPoint = CGPoint(x: 0.5, y: 0.5), on canvas: Canvas) {
    let height = width * CGFloat(screen.height) / CGFloat(screen.width)
    let border: CGFloat = 12
    let frame = CGRect(x: (size.width - width) / 2 - border, y: top - border,
                       width: width + border * 2, height: height + border * 2)
    let radius = width * 0.125
    canvas.raised(frame, card, radius: radius + border, lift: 16, blur: 60)

    let screenRect = frame.insetBy(dx: border, dy: border)
    canvas.context.saveGState()
    canvas.clip(screenRect, radius: radius)
    let z = CGFloat(zoom)
    let fx = screenRect.minX + screenRect.width * focus.x, fy = screenRect.minY + screenRect.height * focus.y
    canvas.draw(screen, in: CGRect(x: fx - (fx - screenRect.minX) * z, y: fy - (fy - screenRect.minY) * z,
                                   width: screenRect.width * z, height: screenRect.height * z))
    canvas.context.restoreGState()
}

/// The pastel label and the headline above each feature, rising in one after the other.
func caption(_ eyebrow: String, _ title: String, tint: Tint, t: Double, on canvas: Canvas) {
    let e = easeOut(progress(t, from: 0.1, over: 0.7))
    let h = easeOut(progress(t, from: 0.22, over: 0.7))
    canvas.layer(alpha: e, offset: CGPoint(x: 0, y: 24 * (1 - e))) {
        chip(eyebrow, fill: tint.soft, color: tint.ink, size: 34, y: 136, on: canvas)
    }
    canvas.layer(alpha: h, offset: CGPoint(x: 0, y: 30 * (1 - h))) {
        canvas.text(canvas.attributed(title, sansBold(68), ink), y: 228)
    }
}

/// A feature shown on the phone: the caption, then the phone rising in while the camera moves in.
func phoneScene(_ eyebrow: String, _ title: String, tint: Tint, screen: CGImage, duration: Double,
                zoom: ClosedRange<Double>, focus: CGPoint) -> Scene {
    Scene(duration: duration) { t, canvas in
        caption(eyebrow, title, tint: tint, t: t, on: canvas)
        let rise = easeOut(progress(t, from: 0.25, over: 0.9))
        let move = easeInOut(progress(t, from: 0.9, over: duration - 0.9))
        canvas.layer(alpha: rise, offset: CGPoint(x: 0, y: 140 * (1 - rise))) {
            phone(screen, top: 420, width: 620, zoom: zoom.lowerBound + (zoom.upperBound - zoom.lowerBound) * move,
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
    // Title: the covers land around the icon on their category pastels, then drift.
    let stickers: [(name: String, tint: Tint, x: CGFloat, y: CGFloat, side: CGFloat, angle: Double, delay: Double)] = [
        ("flowers", rose, 250, 330, 300, -7, 0.0),
        ("celebration", apricot, 840, 300, 270, 6, 0.12),
        ("journal", mint, 140, 720, 210, -5, 0.24),
        ("everyday", lemon, 940, 760, 210, 7, 0.36),
        ("coast", sky, 210, 1560, 290, 5, 0.48),
        ("companionship", lavender, 860, 1600, 300, -6, 0.6),
    ]
    let title = Scene(duration: 3.6) { t, canvas in
        for (index, sticker) in stickers.enumerated() {
            let p = progress(t, from: sticker.delay, over: 0.8)
            let drift = CGFloat(sin((t + Double(index)) * 1.3)) * 6
            canvas.layer(alpha: clamp(p / 0.35), offset: CGPoint(x: 0, y: drift),
                         scale: 0.8 + 0.2 * spring(p), rotation: sticker.angle - 8 * (1 - spring(p)),
                         anchor: CGPoint(x: sticker.x, y: sticker.y)) {
                coverTile(assets.covers[sticker.name]!, tint: sticker.tint, center: CGPoint(x: sticker.x, y: sticker.y),
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
            canvas.text(canvas.attributed("温柔记住每一个重要的日子", sansBold(48), ink2, kern: 2), y: 1070)
        }
    }

    // The countdown, set like the app's day detail (DetailView.countdown, on 2026-04-23): it counts up to
    // the days left, then a tap on the number steps through the units and back.
    let units: [(name: String, value: Int, unit: String, at: Double)] = [
        ("天", 172, "天", 0),
        ("周", 24, "周 4 天", 2.6),
        ("月", 5, "个月 19 天", 3.3),
        ("小时", 4_128, "小时", 4.0),
        ("天", 172, "天", 4.7),
    ]
    let countdown = Scene(duration: 5.6) { t, canvas in
        caption("倒数", "离那一天，还有多少天", tint: rose, t: t, on: canvas)
        let rise = easeOut(progress(t, from: 0.25, over: 0.9))
        let count = easeOut(progress(t, from: 0.7, over: 1.4))
        canvas.layer(alpha: rise, offset: CGPoint(x: 0, y: 100 * (1 - rise))) {
            let cover = CGRect(x: 90, y: 400, width: 900, height: 520)
            canvas.fill(cover, rose.soft, radius: 56)
            canvas.draw(assets.covers["flowers"]!, in: CGRect(x: cover.midX - 230, y: cover.midY - 230, width: 460, height: 460))

            chip("爱情", fill: rose.soft, color: rose.ink, size: 30, x: 90, y: 966, on: canvas)
            canvas.text(canvas.attributed("结婚纪念日", sansBold(80), ink, align: .left), x: 90, y: 1040, width: 900)
            canvas.text(canvas.attributed("2026年10月12日 星期一 · 第7周年", sans(34), muted, align: .left),
                        x: 90, y: 1160, width: 900)

            // The current unit, and the one it is leaving while the number rolls over.
            let current = units.lastIndex { t >= $0.at }!
            let roll = current == 0 ? 1 : easeOut(progress(t, from: units[current].at, over: 0.3))
            let baseline: CGFloat = 1500
            let lead = canvas.attributed("还有", sansBold(40), ink, align: .left)
            func number(_ index: Int) -> NSAttributedString {
                let entry = units[index]
                let value = index == 0 ? Int((Double(entry.value) * count).rounded()) : entry.value
                return canvas.attributed(grouped.string(from: NSNumber(value: value))!,
                                         numeral(entry.value >= 1_000 ? 236 : 300), ink, align: .left)
            }
            func row(_ index: Int, alpha: Double, shift: CGFloat) {
                let unit = canvas.attributed(units[index].unit, sansBold(50), ink, align: .left)
                canvas.layer(alpha: alpha, offset: CGPoint(x: 0, y: shift)) {
                    var x: CGFloat = 90
                    for part in [lead, number(index), unit] {
                        let font = part.attribute(.font, at: 0, effectiveRange: nil) as! NSFont
                        canvas.text(part, x: x, y: baseline - font.ascender, width: 900)
                        x += canvas.measure(part).width + 18
                    }
                }
            }
            if roll < 1 { row(current - 1, alpha: 1 - roll, shift: -60 * roll) }
            row(current, alpha: roll, shift: 60 * (1 - roll))

            // A tap on the number before each change of unit, centred on the number it changes.
            for (index, entry) in units.enumerated().dropFirst() {
                let p = progress(t, from: entry.at - 0.15, over: 0.6)
                guard p > 0, p < 1 else { continue }
                let centerX = 90 + canvas.measure(lead).width + 18 + canvas.measure(number(index - 1)).width / 2
                let radius = 40 + 120 * easeOut(p)
                canvas.context.setStrokeColor(ink.withAlphaComponent(0.3 * (1 - p)).cgColor)
                canvas.context.setLineWidth(6)
                canvas.context.strokeEllipse(in: CGRect(x: centerX - radius, y: 1400 - radius, width: radius * 2, height: radius * 2))
            }

            let hint = canvas.attributed("轻点数字切换", sans(30), muted, align: .left)
            canvas.text(hint, x: 90, y: 1590, width: 900)
            var x = 90 + canvas.measure(hint).width + 18
            for name in ["天", "周", "月", "小时"] {
                let selected = name == units[current].name
                let label = canvas.attributed(name, sansBold(30), selected ? card : ink2)
                let width = canvas.measure(label).width + 44
                let rect = CGRect(x: x, y: 1580, width: width, height: 60)
                canvas.fill(rect, selected ? ink : paper2, radius: 30)
                canvas.text(label, x: rect.minX, y: rect.minY + 9, width: rect.width)
                x += width + 12
            }

            // The first row of the facts below it.
            for (index, fact) in [("日期", "10月12日 星期一"), ("农历", "九月初三")].enumerated() {
                let rect = CGRect(x: 90 + CGFloat(index) * 460, y: 1700, width: 440, height: 150)
                canvas.fill(rect, card, radius: 36)
                canvas.text(canvas.attributed(fact.0, sans(30), muted, align: .left), x: rect.minX + 34, y: rect.minY + 24,
                            width: rect.width - 68)
                canvas.text(canvas.attributed(fact.1, sansBold(42), ink, align: .left), x: rect.minX + 34, y: rect.minY + 70,
                            width: rect.width - 68)
            }
        }
    }

    // Privacy: a zero on an ink card, as on the product site.
    let promises = ["无需账号", "无广告", "无追踪", "无第三方 SDK"]
    let privacy = Scene(duration: 3.4) { t, canvas in
        let rise = easeOut(progress(t, from: 0.0, over: 0.7))
        canvas.layer(alpha: rise, offset: CGPoint(x: 0, y: 80 * (1 - rise))) {
            canvas.fill(CGRect(x: 60, y: 290, width: 960, height: 1260), ink, radius: 72)
        }
        let zero = progress(t, from: 0.2, over: 0.9)
        canvas.layer(alpha: clamp(zero / 0.3), scale: 0.6 + 0.4 * spring(zero), anchor: CGPoint(x: 540, y: 690)) {
            canvas.text(canvas.attributed("0", numeral(520), card), y: 380)
        }
        let head = easeOut(progress(t, from: 0.5, over: 0.8))
        canvas.layer(alpha: head, offset: CGPoint(x: 0, y: 30 * (1 - head))) {
            canvas.text(canvas.attributed("不收集任何数据", sansBold(76), card), y: 1030)
            canvas.text(canvas.attributed("日子、照片和设置只保存在\n你的设备和你自己的 iCloud 中", sans(42), NSColor(hex: 0xE3E1E8),
                                          lineHeight: 66), y: 1150)
        }
        let labels = promises.map { canvas.attributed($0, sansBold(34), card) }
        let widths = labels.map { canvas.measure($0).width + 56 }
        var x = (size.width - widths.reduce(0, +) - CGFloat(promises.count - 1) * 16) / 2
        for (index, label) in labels.enumerated() {
            let p = progress(t, from: 0.95 + Double(index) * 0.12, over: 0.7)
            let rect = CGRect(x: x, y: 1350, width: widths[index], height: 76)
            canvas.layer(alpha: clamp(p / 0.3), scale: 0.7 + 0.3 * spring(p), anchor: CGPoint(x: rect.midX, y: rect.midY)) {
                canvas.fill(rect, card.withAlphaComponent(0.12), radius: 38)
                canvas.text(label, x: rect.minX, y: rect.minY + 14, width: rect.width)
            }
            x += widths[index] + 16
        }
    }

    // The end card: the name, then where to find it.
    let end = Scene(duration: 3.6) { t, canvas in
        let pop = progress(t, from: 0.1, over: 0.8)
        canvas.layer(alpha: clamp(pop / 0.3), scale: 0.6 + 0.4 * spring(pop), anchor: CGPoint(x: 540, y: 640)) {
            icon(assets, center: CGPoint(x: 540, y: 640), side: 240, on: canvas)
        }
        let name = easeOut(progress(t, from: 0.35, over: 0.8))
        canvas.layer(alpha: name, offset: CGPoint(x: 0, y: 30 * (1 - name))) {
            canvas.text(canvas.attributed("时光", sansBold(132), ink, kern: 8), y: 800)
            canvas.text(canvas.attributed("温柔记住每一个重要的日子", sansBold(46), ink2, kern: 2), y: 1000)
        }
        let soon = easeOut(progress(t, from: 0.7, over: 0.8))
        canvas.layer(alpha: soon, offset: CGPoint(x: 0, y: 24 * (1 - soon))) {
            chip("即将登陆 App Store", fill: ink, color: card, size: 42, y: 1150, on: canvas)
            canvas.text(canvas.attributed("免费 · iPhone · iOS 17 及以上", sans(38), ink2), y: 1290)
            canvas.text(canvas.attributed("days.gooday.dev", sans(36), muted, kern: 1), y: 1360)
        }
    }

    return [
        title,
        phoneScene("将至", "重要的日子，都放在这里", tint: apricot, screen: assets.home, duration: 3.8,
                   zoom: 1.0...1.14, focus: CGPoint(x: 0.5, y: 0.3)),
        countdown,
        phoneScene("已过", "走过的日子，一天天正数", tint: lavender, screen: assets.past, duration: 3.8,
                   zoom: 1.0...1.16, focus: CGPoint(x: 0.5, y: 0.3)),
        phoneScene("农历与节气", "农历生日，也不会忘", tint: sky, screen: assets.calendar, duration: 3.8,
                   zoom: 1.0...1.3, focus: CGPoint(x: 0.5, y: 0.36)),
        phoneScene("小组件", "放在主屏幕，抬头就看见", tint: apricot, screen: assets.widgets, duration: 3.4,
                   zoom: 1.0...1.2, focus: CGPoint(x: 0.5, y: 0.5)),
        phoneScene("分享卡片", "做成卡片，分享给重要的人", tint: sky, screen: assets.share, duration: 3.6,
                   zoom: 1.0...1.24, focus: CGPoint(x: 0.5, y: 0.6)),
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
