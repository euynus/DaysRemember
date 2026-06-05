import SwiftUI
import UIKit

/// One of the prototype's CSS `.photo-*` gradient classes.
enum PhotoStyle: String, Codable, CaseIterable, Hashable {
    case wedding, baby, birthday, japan, study, memorial, work, pet, home, health
    case sketchLove, sketchFamily, sketchTravel, sketchWork, sketchLife
    case sketchMountain, sketchSea, sketchCafe, sketchGarden

    static let categorySketchPresets: [PhotoStyle] = [
        .sketchLove, .sketchFamily, .sketchTravel, .sketchWork, .sketchLife
    ]

    var displayName: String {
        switch self {
        case .wedding: return "纪念日"
        case .baby: return "宝宝"
        case .birthday: return "生日"
        case .japan: return "旅行"
        case .study: return "学习"
        case .memorial: return "回忆"
        case .work: return "工作"
        case .pet: return "宠物"
        case .home: return "生活"
        case .health: return "健康"
        case .sketchLove: return "手绘爱情"
        case .sketchFamily: return "手绘家人"
        case .sketchTravel: return "手绘旅行"
        case .sketchWork: return "手绘工作"
        case .sketchLife: return "手绘生活"
        case .sketchMountain: return "手绘山野"
        case .sketchSea: return "手绘海边"
        case .sketchCafe: return "手绘咖啡"
        case .sketchGarden: return "手绘花园"
        }
    }

    /// Preset cover art: a scrapbook-style paper collage built from the original
    /// gradient/hand-drawn scene plus stickers, a handwritten note, and soft shadows.
    @ViewBuilder
    func background() -> some View {
        ScrapbookTemplateBackground(style: self)
    }
}

private enum HandDrawnScene: String {
    case love, family, travel, work, life
    case mountain, sea, cafe, garden
}

private extension PhotoStyle {
    var handDrawnScene: HandDrawnScene? {
        switch self {
        case .sketchLove: return .love
        case .sketchFamily: return .family
        case .sketchTravel: return .travel
        case .sketchWork: return .work
        case .sketchLife: return .life
        case .sketchMountain: return .mountain
        case .sketchSea: return .sea
        case .sketchCafe: return .cafe
        case .sketchGarden: return .garden
        default: return nil
        }
    }

    var supportingStyle: PhotoStyle {
        switch self {
        case .wedding: return .baby
        case .baby: return .birthday
        case .birthday: return .home
        case .japan: return .sketchTravel
        case .study: return .work
        case .memorial: return .sketchLife
        case .work: return .study
        case .pet: return .home
        case .home: return .sketchFamily
        case .health: return .sketchGarden
        case .sketchLove: return .wedding
        case .sketchFamily: return .home
        case .sketchTravel: return .japan
        case .sketchWork: return .work
        case .sketchLife: return .birthday
        case .sketchMountain: return .sketchGarden
        case .sketchSea: return .sketchTravel
        case .sketchCafe: return .home
        case .sketchGarden: return .health
        }
    }

    var primarySticker: StickerName {
        switch self {
        case .wedding, .sketchLove: return .heart
        case .baby, .sketchFamily: return .balloon
        case .birthday: return .cake
        case .japan, .sketchTravel, .sketchMountain, .sketchSea: return .plane
        case .study: return .cap
        case .work, .sketchWork: return .star
        case .pet: return .paw
        case .home, .sketchLife, .sketchCafe, .sketchGarden: return .house
        case .memorial, .health: return .sparkle
        }
    }

    var secondarySticker: StickerName {
        switch self {
        case .wedding: return .ring
        case .baby: return .star
        case .birthday: return .gift
        case .japan, .sketchTravel: return .camera
        case .study, .sketchWork: return .star
        case .memorial: return .camera
        case .work: return .cap
        case .pet: return .heart
        case .home, .sketchFamily, .sketchLife: return .sun
        case .health, .sketchGarden: return .heart
        case .sketchLove: return .ring
        case .sketchMountain: return .sun
        case .sketchSea: return .camera
        case .sketchCafe: return .camera
        }
    }

    var noteText: String {
        switch self {
        case .wedding: return "Love\nDay"
        case .baby: return "Tiny\nJoy"
        case .birthday: return "Happy\nDay"
        case .japan, .sketchTravel: return "Nice\nView"
        case .study: return "Study\nPlan"
        case .memorial: return "Soft\nMemory"
        case .work, .sketchWork: return "Work\nPlan"
        case .pet: return "Pet\nLove"
        case .home, .sketchFamily, .sketchLife: return "Home\nLife"
        case .health: return "Keep\nWell"
        case .sketchLove: return "Sweet\nNote"
        case .sketchMountain: return "Fresh\nAir"
        case .sketchSea: return "Sea\nDay"
        case .sketchCafe: return "Cafe\nTime"
        case .sketchGarden: return "Bloom\nDay"
        }
    }

    var notePalette: (paper: Color, ink: Color) {
        switch self {
        case .wedding, .sketchLove:
            return (Theme.notePink, Theme.notePinkInk)
        case .baby, .birthday, .home, .sketchFamily, .sketchLife:
            return (Theme.noteYellow, Theme.noteYellowInk)
        case .japan, .study, .sketchTravel, .sketchSea:
            return (Theme.noteBlue, Theme.noteBlueInk)
        case .work, .health, .sketchWork, .sketchMountain, .sketchGarden:
            return (Theme.noteGreen, Theme.noteGreenInk)
        case .memorial, .pet, .sketchCafe:
            return (Theme.notePeach, Theme.notePeachInk)
        }
    }
}

private struct ScrapbookTemplateBackground: View {
    let style: PhotoStyle

    /// Below this rendered side length the multi-layer collage is illegible and reads
    /// as clutter, so we fall back to the clean luminous photo. The full scrapbook
    /// collage is reserved for large single-day showcase surfaces (Detail/Share).
    private static let collageMinSide: CGFloat = 248

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let side = max(1, min(size.width, size.height))

            if side < Self.collageMinSide {
                // Feed/peek/picker sizes: clean photo, no grain (perf on scrolling lists).
                PhotoTemplateArtwork(style: style, grain: false)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                collage(in: size, side: side)
            }
        }
    }

    private func collage(in size: CGSize, side: CGFloat) -> some View {
        let mainWidth = size.width * 0.76
        let mainHeight = size.height * 0.68
        let supportWidth = size.width * 0.62
        let supportHeight = size.height * 0.47

        return ZStack {
                ScrapbookPaperBackground()

                TornPaperStrip()
                    .fill(Color.white.opacity(0.98))
                    .frame(width: size.width * 1.18, height: size.height * 0.26)
                    .rotationEffect(.degrees(-4))
                    .offset(x: -size.width * 0.03, y: -size.height * 0.33)
                    .shadow(color: Theme.ink.opacity(0.12), radius: side * 0.018, x: 0, y: side * 0.015)

                TemplatePhotoCard(style: style.supportingStyle)
                    .frame(width: supportWidth, height: supportHeight)
                    .rotationEffect(.degrees(7))
                    .offset(x: size.width * 0.17, y: -size.height * 0.06)
                    .opacity(0.82)

                TemplatePhotoCard(style: style)
                    .frame(width: mainWidth, height: mainHeight)
                    .rotationEffect(.degrees(-5))
                    .offset(x: -size.width * 0.09, y: size.height * 0.16)

                // A single small sticker for charm. The internal note + tape were
                // removed: the screens that show this cover (Detail/Share) add their
                // own countdown sticky, washi tape, and sticker, so duplicating them
                // here read as clutter — and the note baked in English copy.
                Sticker(name: style.primarySticker, size: side * 0.2, rotate: -12)
                    .offset(x: -size.width * 0.28, y: size.height * 0.24)
                    .zIndex(5)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}

private struct ScrapbookPaperBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xF7F7F8), Theme.bg, Color(hex: 0xE4E3E7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.white.opacity(0.72), Color.white.opacity(0)],
                center: .top,
                startRadius: 0,
                endRadius: 260
            )
            PhotoGrain()
                .opacity(0.18)
        }
    }
}

private struct TemplatePhotoCard: View {
    let style: PhotoStyle

    var body: some View {
        GeometryReader { proxy in
            let side = max(1, min(proxy.size.width, proxy.size.height))
            let padding = max(4, side * 0.045)
            let radius = max(8, side * 0.075)

            PhotoTemplateArtwork(style: style)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: radius + padding * 0.7, style: .continuous)
                        .fill(Color.white)
                )
                .shadow(color: Theme.ink.opacity(0.08), radius: side * 0.012, x: 0, y: side * 0.006)
                .shadow(color: Theme.ink.opacity(0.14), radius: side * 0.070, x: 0, y: side * 0.050)
        }
    }
}

private struct PhotoTemplateArtwork: View {
    let style: PhotoStyle
    var grain: Bool = true

    @ViewBuilder
    var body: some View {
        if let scene = style.handDrawnScene {
            HandDrawnPhotoBackground(scene: scene)
        } else {
            GradientPhotoView(spec: PhotoStyle.gradientSpec(for: style), grain: grain)
        }
    }
}

private struct TemplateNote: View {
    let style: PhotoStyle

    var body: some View {
        GeometryReader { proxy in
            let side = max(1, min(proxy.size.width, proxy.size.height))
            let palette = style.notePalette

            Text(style.noteText)
                .font(Theme.hand(max(11, side * 0.32)))
                .lineSpacing(-side * 0.035)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.48)
                .foregroundStyle(palette.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, side * 0.09)
                .background(
                    RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
                        .fill(palette.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
                                .strokeBorder(palette.ink.opacity(0.28), lineWidth: max(1, side * 0.018))
                        )
                )
                .shadow(color: Theme.ink.opacity(0.14), radius: side * 0.10, x: 0, y: side * 0.08)
                .overlay(alignment: .top) {
                    Paperclip(size: max(12, side * 0.24), color: Color(hex: 0x89909A))
                        .offset(y: -side * 0.23)
                }
        }
    }
}

private struct ScaledTape: View {
    var color: Color

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(color)
                .overlay(alignment: .leading) { tornEdge(in: proxy.size) }
                .overlay(alignment: .trailing) { tornEdge(in: proxy.size) }
                .shadow(color: Theme.ink.opacity(0.10), radius: 1, x: 0, y: 1)
        }
    }

    private func tornEdge(in size: CGSize) -> some View {
        Rectangle()
            .strokeBorder(style: StrokeStyle(lineWidth: max(1, size.height * 0.08), dash: [3, 2]))
            .foregroundStyle(Color.white.opacity(0.55))
            .frame(width: max(1, size.width * 0.04))
    }
}

private struct TornPaperStrip: Shape {
    func path(in rect: CGRect) -> Path {
        let tearY = rect.minY + rect.height * 0.72
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: tearY))

        let steps = 11
        for index in stride(from: steps, through: 0, by: -1) {
            let progress = CGFloat(index) / CGFloat(steps)
            let x = rect.minX + rect.width * progress
            let variance = index.isMultiple(of: 2) ? rect.height * 0.20 : -rect.height * 0.10
            path.addLine(to: CGPoint(x: x, y: tearY + variance))
        }

        path.closeSubpath()
        return path
    }
}

/// Process-wide raster cache for the hand-drawn covers. Each scene has ~50-200
/// path ops; rendering once and reusing the bitmap saves the redraw on every
/// body re-eval (scrolls, taps, anything that re-validates the home grid).
private enum HandDrawnRasterCache {
    static let storage: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 16
        return cache
    }()
}

@MainActor
private struct HandDrawnPhotoBackground: View {
    let scene: HandDrawnScene

    var body: some View {
        let key = scene.rawValue as NSString
        let raster = HandDrawnRasterCache.storage.object(forKey: key) ?? renderAndCache(key: key)
        Image(uiImage: raster)
            .resizable()
            .scaledToFill()
    }

    /// Synchronous one-shot render via ImageRenderer. Runs at most once per scene
    /// per app session — subsequent body evals hit the NSCache fast path.
    private func renderAndCache(key: NSString) -> UIImage {
        let renderer = ImageRenderer(content: rawContent.frame(width: 512, height: 512))
        renderer.scale = 2
        guard let image = renderer.uiImage else { return UIImage() }
        HandDrawnRasterCache.storage.setObject(image, forKey: key)
        return image
    }

    private var rawContent: some View {
        ZStack {
            LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                switch scene {
                case .love:
                    drawLove(in: &context, size: size)
                case .family:
                    drawFamily(in: &context, size: size)
                case .travel:
                    drawTravel(in: &context, size: size)
                case .work:
                    drawWork(in: &context, size: size)
                case .life:
                    drawLife(in: &context, size: size)
                case .mountain:
                    drawMountain(in: &context, size: size)
                case .sea:
                    drawSea(in: &context, size: size)
                case .cafe:
                    drawCafe(in: &context, size: size)
                case .garden:
                    drawGarden(in: &context, size: size)
                }
            }
        }
    }

    private var palette: [Color] {
        switch scene {
        case .love:
            return [Color(hex: 0xFCE3DC), Color(hex: 0xEFA4A6), Color(hex: 0xB85C62)]
        case .family:
            return [Color(hex: 0xFFF0C8), Color(hex: 0xE6BE70), Color(hex: 0xA06D42)]
        case .travel:
            return [Color(hex: 0xEFE7D5), Color(hex: 0xB7CED9), Color(hex: 0x687FA7)]
        case .work:
            return [Color(hex: 0xE7F0D8), Color(hex: 0xA9C5A4), Color(hex: 0x5F856E)]
        case .life:
            return [Color(hex: 0xF8E2CC), Color(hex: 0xE6A478), Color(hex: 0xB76642)]
        case .mountain:
            return [Color(hex: 0xF6E9D1), Color(hex: 0xBFD6C6), Color(hex: 0x6E9A82)]
        case .sea:
            return [Color(hex: 0xF9E7C7), Color(hex: 0xB9D7DD), Color(hex: 0x5B8CA0)]
        case .cafe:
            return [Color(hex: 0xF7D7C0), Color(hex: 0xDDA37F), Color(hex: 0x8E5D47)]
        case .garden:
            return [Color(hex: 0xF7EAC8), Color(hex: 0xC8DBA4), Color(hex: 0x73966D)]
        }
    }

    private func drawLove(in context: inout GraphicsContext, size: CGSize) {
        let ink = Color(hex: 0x6B3138)
        let rose = Color(hex: 0xC8616B).opacity(0.74)
        let cream = Color(hex: 0xFFF2DD).opacity(0.72)

        var envelope = Path()
        envelope.move(to: point(0.18, 0.46, size))
        envelope.addLine(to: point(0.78, 0.36, size))
        envelope.addLine(to: point(0.86, 0.68, size))
        envelope.addLine(to: point(0.26, 0.78, size))
        envelope.closeSubpath()
        context.fill(envelope, with: .color(cream))
        stroke(envelope, in: &context, color: ink.opacity(0.58), width: line(size, 0.009), jitter: true)
        stroke(polyline([(0.20, 0.47), (0.52, 0.61), (0.78, 0.37)], size),
               in: &context, color: ink.opacity(0.36), width: line(size, 0.007), jitter: true)

        context.fill(heartPath(center: point(0.54, 0.40, size), scale: min(size.width, size.height) * 0.24),
                     with: .color(rose))
        stroke(heartPath(center: point(0.54, 0.40, size), scale: min(size.width, size.height) * 0.24),
               in: &context, color: ink.opacity(0.52), width: line(size, 0.008), jitter: true)

        context.fill(heartPath(center: point(0.26, 0.25, size), scale: min(size.width, size.height) * 0.10),
                     with: .color(Color.white.opacity(0.45)))
        context.fill(heartPath(center: point(0.78, 0.22, size), scale: min(size.width, size.height) * 0.08),
                     with: .color(Color.white.opacity(0.38)))
        stroke(polyline([(0.18, 0.88), (0.40, 0.83), (0.64, 0.86), (0.84, 0.80)], size),
               in: &context, color: ink.opacity(0.32), width: line(size, 0.012), jitter: true)
    }

    private func drawFamily(in context: inout GraphicsContext, size: CGSize) {
        let ink = Color(hex: 0x65401F)
        let house = Color(hex: 0xF8E2B1).opacity(0.78)
        let roof = Color(hex: 0xA65F3E).opacity(0.76)
        let green = Color(hex: 0x6F8A56).opacity(0.72)

        var roofPath = Path()
        roofPath.move(to: point(0.18, 0.50, size))
        roofPath.addLine(to: point(0.50, 0.24, size))
        roofPath.addLine(to: point(0.82, 0.50, size))
        roofPath.closeSubpath()
        context.fill(roofPath, with: .color(roof))
        stroke(roofPath, in: &context, color: ink.opacity(0.55), width: line(size, 0.01), jitter: true)

        let body = rectPath(0.25, 0.48, 0.50, 0.32, size)
        context.fill(body, with: .color(house))
        stroke(body, in: &context, color: ink.opacity(0.50), width: line(size, 0.009), jitter: true)
        stroke(rectPath(0.34, 0.56, 0.12, 0.12, size), in: &context, color: ink.opacity(0.36), width: line(size, 0.007))
        stroke(rectPath(0.55, 0.56, 0.12, 0.24, size), in: &context, color: ink.opacity(0.42), width: line(size, 0.007))

        for person in [(0.37, 0.84, 0.040), (0.50, 0.83, 0.048), (0.63, 0.85, 0.036)] as [(CGFloat, CGFloat, CGFloat)] {
            drawPerson(x: person.0, y: person.1, radius: person.2, in: &context, size: size,
                       color: ink.opacity(0.66))
        }

        drawTree(x: 0.13, y: 0.80, in: &context, size: size, color: green, ink: ink)
        drawTree(x: 0.87, y: 0.78, in: &context, size: size, color: green.opacity(0.82), ink: ink)
        stroke(polyline([(0.18, 0.88), (0.82, 0.88)], size), in: &context, color: ink.opacity(0.28), width: line(size, 0.011), jitter: true)
    }

    private func drawTravel(in context: inout GraphicsContext, size: CGSize) {
        let ink = Color(hex: 0x2F4766)
        let mountain = Color(hex: 0x6D86A4).opacity(0.58)
        let road = Color(hex: 0xF3D49A).opacity(0.78)
        let accent = Color(hex: 0xB85F44).opacity(0.80)

        var hills = Path()
        hills.move(to: point(-0.04, 0.68, size))
        hills.addCurve(to: point(0.28, 0.34, size), control1: point(0.06, 0.60, size), control2: point(0.16, 0.40, size))
        hills.addCurve(to: point(0.50, 0.56, size), control1: point(0.38, 0.40, size), control2: point(0.41, 0.54, size))
        hills.addCurve(to: point(0.79, 0.38, size), control1: point(0.60, 0.52, size), control2: point(0.69, 0.38, size))
        hills.addCurve(to: point(1.04, 0.66, size), control1: point(0.90, 0.43, size), control2: point(0.96, 0.58, size))
        hills.addLine(to: point(1.04, 1.04, size))
        hills.addLine(to: point(-0.04, 1.04, size))
        context.fill(hills, with: .color(mountain))
        stroke(hills, in: &context, color: ink.opacity(0.45), width: line(size, 0.01), jitter: true)

        stroke(polyline([(0.46, 1.04), (0.51, 0.82), (0.57, 0.70), (0.60, 0.58)], size),
               in: &context, color: road, width: line(size, 0.045))
        stroke(polyline([(0.44, 0.23), (0.52, 0.19), (0.70, 0.24), (0.86, 0.19)], size),
               in: &context, color: ink.opacity(0.45), width: line(size, 0.007))

        stroke(suitcasePath(x: 0.18, y: 0.68, size: size), in: &context,
               color: ink.opacity(0.62), width: line(size, 0.009), jitter: true)
        context.fill(Path(ellipseIn: rect(0.72, 0.17, 0.14, 0.14, size)), with: .color(accent))
        stroke(polyline([(0.68, 0.29), (0.82, 0.25), (0.90, 0.29)], size),
               in: &context, color: ink.opacity(0.36), width: line(size, 0.008), jitter: true)
    }

    private func drawWork(in context: inout GraphicsContext, size: CGSize) {
        let ink = Color(hex: 0x2F4B3F)
        let paper = Color(hex: 0xF3F0D8).opacity(0.76)
        let screen = Color(hex: 0xDCE9D4).opacity(0.78)
        let accent = Color(hex: 0x6F9A75).opacity(0.72)

        let laptop = rectPath(0.26, 0.36, 0.48, 0.28, size)
        context.fill(laptop, with: .color(screen))
        stroke(laptop, in: &context, color: ink.opacity(0.58), width: line(size, 0.009), jitter: true)
        stroke(polyline([(0.18, 0.70), (0.82, 0.70)], size),
               in: &context, color: ink.opacity(0.58), width: line(size, 0.018), jitter: true)
        stroke(polyline([(0.34, 0.49), (0.45, 0.49), (0.50, 0.55), (0.62, 0.44)], size),
               in: &context, color: accent, width: line(size, 0.012), jitter: true)

        var note = Path()
        note.move(to: point(0.12, 0.20, size))
        note.addLine(to: point(0.36, 0.16, size))
        note.addLine(to: point(0.40, 0.40, size))
        note.addLine(to: point(0.16, 0.44, size))
        note.closeSubpath()
        context.fill(note, with: .color(paper))
        stroke(note, in: &context, color: ink.opacity(0.38), width: line(size, 0.007), jitter: true)
        for y in [0.24, 0.30, 0.36] as [CGFloat] {
            stroke(polyline([(0.18, y), (0.34, y - 0.03)], size), in: &context,
                   color: ink.opacity(0.25), width: line(size, 0.005))
        }

        stroke(rectPath(0.68, 0.20, 0.14, 0.16, size), in: &context, color: ink.opacity(0.44), width: line(size, 0.008), jitter: true)
        stroke(polyline([(0.71, 0.20), (0.71, 0.16), (0.79, 0.16), (0.79, 0.20)], size),
               in: &context, color: ink.opacity(0.44), width: line(size, 0.007))
    }

    private func drawLife(in context: inout GraphicsContext, size: CGSize) {
        let ink = Color(hex: 0x6E3C25)
        let mug = Color(hex: 0xFFF1DA).opacity(0.74)
        let plant = Color(hex: 0x668456).opacity(0.78)
        let accent = Color(hex: 0xD9794E).opacity(0.70)

        stroke(polyline([(0.16, 0.80), (0.84, 0.80)], size),
               in: &context, color: ink.opacity(0.40), width: line(size, 0.014), jitter: true)

        var cup = Path()
        cup.move(to: point(0.36, 0.50, size))
        cup.addQuadCurve(to: point(0.62, 0.50, size), control: point(0.49, 0.55, size))
        cup.addQuadCurve(to: point(0.57, 0.72, size), control: point(0.62, 0.69, size))
        cup.addQuadCurve(to: point(0.41, 0.72, size), control: point(0.49, 0.76, size))
        cup.addQuadCurve(to: point(0.36, 0.50, size), control: point(0.35, 0.66, size))
        context.fill(cup, with: .color(mug))
        stroke(cup, in: &context, color: ink.opacity(0.58), width: line(size, 0.010), jitter: true)
        stroke(Path(ellipseIn: rect(0.58, 0.55, 0.12, 0.12, size)), in: &context,
               color: ink.opacity(0.44), width: line(size, 0.008), jitter: true)

        for leaf in [(0.24, 0.45), (0.29, 0.38), (0.33, 0.48), (0.25, 0.55)] {
            stroke(leafPath(x: leaf.0, y: leaf.1, size: size), in: &context, color: plant, width: line(size, 0.012))
        }
        stroke(polyline([(0.29, 0.62), (0.29, 0.42)], size), in: &context, color: plant, width: line(size, 0.007))
        context.fill(heartPath(center: point(0.73, 0.40, size), scale: min(size.width, size.height) * 0.12),
                     with: .color(accent))

        for sparkle in [(0.18, 0.20), (0.78, 0.20), (0.84, 0.52)] as [(CGFloat, CGFloat)] {
            drawSparkle(x: sparkle.0, y: sparkle.1, in: &context, size: size, color: Color.white.opacity(0.52))
        }
    }

    private func drawMountain(in context: inout GraphicsContext, size: CGSize) {
        let ink = Color(hex: 0x314C43)
        let snow = Color.white.opacity(0.58)
        let sun = Color(hex: 0xE8A75B).opacity(0.85)

        context.fill(Path(ellipseIn: rect(0.70, 0.13, 0.18, 0.18, size)), with: .color(sun))
        stroke(polyline([(0.64, 0.17), (0.70, 0.12), (0.78, 0.16), (0.84, 0.12)], size), in: &context, color: ink.opacity(0.42), width: line(size, 0.006))

        var back = Path()
        back.move(to: point(0.02, 0.62, size))
        back.addCurve(to: point(0.35, 0.35, size), control1: point(0.12, 0.54, size), control2: point(0.22, 0.38, size))
        back.addCurve(to: point(0.62, 0.56, size), control1: point(0.46, 0.42, size), control2: point(0.50, 0.54, size))
        back.addCurve(to: point(1.02, 0.34, size), control1: point(0.76, 0.50, size), control2: point(0.84, 0.36, size))
        back.addLine(to: point(1.02, 1.02, size))
        back.addLine(to: point(0.02, 1.02, size))
        context.fill(back, with: .color(Color(hex: 0x789B82).opacity(0.55)))
        stroke(back, in: &context, color: ink.opacity(0.38), width: line(size, 0.008), jitter: true)

        var front = Path()
        front.move(to: point(-0.04, 0.76, size))
        front.addCurve(to: point(0.29, 0.43, size), control1: point(0.08, 0.68, size), control2: point(0.16, 0.47, size))
        front.addCurve(to: point(0.49, 0.68, size), control1: point(0.38, 0.50, size), control2: point(0.41, 0.65, size))
        front.addCurve(to: point(0.79, 0.46, size), control1: point(0.60, 0.62, size), control2: point(0.67, 0.47, size))
        front.addCurve(to: point(1.04, 0.70, size), control1: point(0.88, 0.50, size), control2: point(0.96, 0.64, size))
        front.addLine(to: point(1.04, 1.04, size))
        front.addLine(to: point(-0.04, 1.04, size))
        context.fill(front, with: .color(Color(hex: 0x426F5F).opacity(0.62)))
        stroke(front, in: &context, color: ink.opacity(0.55), width: line(size, 0.01), jitter: true)

        stroke(polyline([(0.25, 0.47), (0.31, 0.54), (0.38, 0.50)], size), in: &context, color: snow, width: line(size, 0.012))
        stroke(polyline([(0.75, 0.48), (0.80, 0.56), (0.87, 0.52)], size), in: &context, color: snow, width: line(size, 0.01))

        for x in [0.14, 0.20, 0.87, 0.93] {
            drawPine(x: x, y: 0.72 + (x.truncatingRemainder(dividingBy: 0.09)), in: &context, size: size, color: ink.opacity(0.7))
        }
        stroke(polyline([(0.47, 1.04), (0.51, 0.82), (0.57, 0.70), (0.60, 0.58)], size), in: &context, color: Color(hex: 0xF0D4A4).opacity(0.8), width: line(size, 0.04))
    }

    private func drawSea(in context: inout GraphicsContext, size: CGSize) {
        let ink = Color(hex: 0x2F5363)
        let sun = Color(hex: 0xE8A75B).opacity(0.9)
        let boat = Color(hex: 0xB85F44).opacity(0.82)

        context.fill(Path(ellipseIn: rect(0.12, 0.14, 0.17, 0.17, size)), with: .color(sun))
        stroke(polyline([(0.04, 0.58), (0.18, 0.55), (0.33, 0.58), (0.48, 0.54), (0.64, 0.58), (0.80, 0.54), (0.98, 0.57)], size),
               in: &context, color: ink.opacity(0.36), width: line(size, 0.01), jitter: true)

        for y in [0.66, 0.75, 0.84] {
            stroke(wave(y: y, size: size), in: &context, color: ink.opacity(0.58), width: line(size, 0.01), jitter: true)
        }

        var hull = Path()
        hull.move(to: point(0.42, 0.58, size))
        hull.addQuadCurve(to: point(0.70, 0.58, size), control: point(0.55, 0.69, size))
        hull.addQuadCurve(to: point(0.42, 0.58, size), control: point(0.55, 0.62, size))
        context.fill(hull, with: .color(boat))
        stroke(hull, in: &context, color: ink.opacity(0.55), width: line(size, 0.008), jitter: true)

        stroke(polyline([(0.55, 0.57), (0.55, 0.32)], size), in: &context, color: ink.opacity(0.62), width: line(size, 0.008))
        var sail = Path()
        sail.move(to: point(0.56, 0.34, size))
        sail.addLine(to: point(0.56, 0.56, size))
        sail.addLine(to: point(0.72, 0.51, size))
        sail.closeSubpath()
        context.fill(sail, with: .color(Color.white.opacity(0.64)))
        stroke(sail, in: &context, color: ink.opacity(0.45), width: line(size, 0.007), jitter: true)

        for x in [0.72, 0.82] {
            stroke(polyline([(x, 0.26), (x + 0.035, 0.23), (x + 0.07, 0.26)], size), in: &context, color: ink.opacity(0.48), width: line(size, 0.006))
        }
    }

    private func drawCafe(in context: inout GraphicsContext, size: CGSize) {
        let ink = Color(hex: 0x5E3529)
        let cream = Color(hex: 0xFFF1DA).opacity(0.72)
        let plant = Color(hex: 0x567A58).opacity(0.78)

        stroke(rectPath(0.12, 0.16, 0.36, 0.32, size), in: &context, color: ink.opacity(0.45), width: line(size, 0.008), jitter: true)
        stroke(polyline([(0.12, 0.32), (0.48, 0.32)], size), in: &context, color: ink.opacity(0.3), width: line(size, 0.006))
        stroke(polyline([(0.30, 0.16), (0.30, 0.48)], size), in: &context, color: ink.opacity(0.3), width: line(size, 0.006))

        var cup = Path()
        cup.move(to: point(0.40, 0.58, size))
        cup.addQuadCurve(to: point(0.67, 0.58, size), control: point(0.54, 0.62, size))
        cup.addQuadCurve(to: point(0.60, 0.80, size), control: point(0.65, 0.76, size))
        cup.addQuadCurve(to: point(0.45, 0.80, size), control: point(0.52, 0.84, size))
        cup.addQuadCurve(to: point(0.40, 0.58, size), control: point(0.39, 0.74, size))
        context.fill(cup, with: .color(cream))
        stroke(cup, in: &context, color: ink.opacity(0.72), width: line(size, 0.01), jitter: true)
        stroke(Path(ellipseIn: rect(0.62, 0.62, 0.13, 0.12, size)), in: &context, color: ink.opacity(0.62), width: line(size, 0.009), jitter: true)
        stroke(polyline([(0.28, 0.84), (0.78, 0.84)], size), in: &context, color: ink.opacity(0.55), width: line(size, 0.012), jitter: true)

        for x in [0.48, 0.54, 0.60] {
            stroke(polyline([(x, 0.51), (x - 0.02, 0.46), (x + 0.01, 0.41)], size), in: &context, color: Color.white.opacity(0.55), width: line(size, 0.009))
        }

        for leaf in [(0.78, 0.33), (0.84, 0.28), (0.88, 0.37), (0.80, 0.43)] {
            stroke(leafPath(x: leaf.0, y: leaf.1, size: size), in: &context, color: plant, width: line(size, 0.013))
        }
        stroke(polyline([(0.84, 0.50), (0.84, 0.30)], size), in: &context, color: plant, width: line(size, 0.008))
    }

    private func drawGarden(in context: inout GraphicsContext, size: CGSize) {
        let ink = Color(hex: 0x405C3B)
        let green = Color(hex: 0x5B874F).opacity(0.74)
        let rose = Color(hex: 0xC96B68).opacity(0.78)
        let yellow = Color(hex: 0xE7B45A).opacity(0.86)

        stroke(polyline([(0.00, 0.72), (0.18, 0.65), (0.36, 0.71), (0.54, 0.63), (0.74, 0.70), (1.00, 0.62)], size),
               in: &context, color: green, width: line(size, 0.018), jitter: true)

        for x in [0.16, 0.30, 0.48, 0.68, 0.84] {
            stroke(polyline([(x, 0.86), (x + 0.02, 0.67)], size), in: &context, color: ink.opacity(0.58), width: line(size, 0.007))
            drawFlower(x: x + 0.02, y: 0.62 + x.truncatingRemainder(dividingBy: 0.08), color: x < 0.5 ? rose : yellow,
                       in: &context, size: size)
        }

        for x in [0.10, 0.56, 0.76, 0.92] {
            stroke(leafPath(x: x, y: 0.78, size: size), in: &context, color: green, width: line(size, 0.011))
        }

        stroke(polyline([(0.58, 0.25), (0.61, 0.20), (0.64, 0.25)], size), in: &context, color: ink.opacity(0.45), width: line(size, 0.006))
        context.fill(Path(ellipseIn: rect(0.54, 0.24, 0.08, 0.05, size)), with: .color(rose.opacity(0.5)))
        context.fill(Path(ellipseIn: rect(0.62, 0.24, 0.08, 0.05, size)), with: .color(yellow.opacity(0.5)))
    }

    private func drawPine(x: CGFloat, y: CGFloat, in context: inout GraphicsContext, size: CGSize, color: Color) {
        stroke(polyline([(x, y), (x, y - 0.18)], size), in: &context, color: color, width: line(size, 0.006))
        for offset in [0.04, 0.08, 0.12] {
            stroke(polyline([(x - offset, y - offset), (x, y - offset - 0.06), (x + offset, y - offset)], size),
                   in: &context, color: color, width: line(size, 0.008))
        }
    }

    private func drawFlower(x: CGFloat, y: CGFloat, color: Color, in context: inout GraphicsContext, size: CGSize) {
        let r = min(size.width, size.height) * 0.026
        let center = point(x, y, size)
        for angle in stride(from: CGFloat(0), to: CGFloat.pi * 2, by: CGFloat.pi / 2) {
            let petal = CGRect(
                x: center.x + cos(angle) * r - r * 0.7,
                y: center.y + sin(angle) * r - r * 0.7,
                width: r * 1.4,
                height: r * 1.4
            )
            context.fill(Path(ellipseIn: petal), with: .color(color))
        }
        context.fill(Path(ellipseIn: CGRect(x: center.x - r * 0.5, y: center.y - r * 0.5, width: r, height: r)),
                     with: .color(Color(hex: 0x6B4A2E).opacity(0.7)))
    }

    private func drawPerson(x: CGFloat, y: CGFloat, radius: CGFloat,
                            in context: inout GraphicsContext, size: CGSize, color: Color) {
        let head = CGRect(
            x: size.width * x - size.width * radius,
            y: size.height * (y - 0.16) - size.width * radius,
            width: size.width * radius * 2,
            height: size.width * radius * 2
        )
        context.fill(Path(ellipseIn: head), with: .color(color))
        stroke(polyline([(x, y - 0.11), (x, y), (x - 0.05, y + 0.05), (x, y), (x + 0.05, y + 0.05)], size),
               in: &context, color: color, width: line(size, 0.008), jitter: true)
    }

    private func drawTree(x: CGFloat, y: CGFloat, in context: inout GraphicsContext,
                          size: CGSize, color: Color, ink: Color) {
        stroke(polyline([(x, y), (x, y - 0.18)], size), in: &context,
               color: ink.opacity(0.40), width: line(size, 0.007))
        for blob in [(x - 0.045, y - 0.16), (x, y - 0.22), (x + 0.045, y - 0.16)] {
            context.fill(Path(ellipseIn: rect(blob.0, blob.1, 0.09, 0.09, size)), with: .color(color))
        }
    }

    private func drawSparkle(x: CGFloat, y: CGFloat, in context: inout GraphicsContext,
                             size: CGSize, color: Color) {
        stroke(polyline([(x, y - 0.06), (x, y + 0.06)], size),
               in: &context, color: color, width: line(size, 0.006))
        stroke(polyline([(x - 0.05, y), (x + 0.05, y)], size),
               in: &context, color: color, width: line(size, 0.006))
    }

    private func suitcasePath(x: CGFloat, y: CGFloat, size: CGSize) -> Path {
        var path = rectPath(x, y, 0.18, 0.16, size)
        path.move(to: point(x + 0.05, y, size))
        path.addLine(to: point(x + 0.05, y - 0.05, size))
        path.addLine(to: point(x + 0.13, y - 0.05, size))
        path.addLine(to: point(x + 0.13, y, size))
        path.move(to: point(x + 0.09, y, size))
        path.addLine(to: point(x + 0.09, y + 0.16, size))
        return path
    }

    private func heartPath(center: CGPoint, scale: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y + scale * 0.34))
        path.addCurve(
            to: CGPoint(x: center.x - scale * 0.52, y: center.y - scale * 0.12),
            control1: CGPoint(x: center.x - scale * 0.42, y: center.y + scale * 0.12),
            control2: CGPoint(x: center.x - scale * 0.56, y: center.y - scale * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y - scale * 0.36),
            control1: CGPoint(x: center.x - scale * 0.44, y: center.y - scale * 0.36),
            control2: CGPoint(x: center.x - scale * 0.12, y: center.y - scale * 0.48)
        )
        path.addCurve(
            to: CGPoint(x: center.x + scale * 0.52, y: center.y - scale * 0.12),
            control1: CGPoint(x: center.x + scale * 0.12, y: center.y - scale * 0.48),
            control2: CGPoint(x: center.x + scale * 0.44, y: center.y - scale * 0.36)
        )
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y + scale * 0.34),
            control1: CGPoint(x: center.x + scale * 0.56, y: center.y - scale * 0.02),
            control2: CGPoint(x: center.x + scale * 0.42, y: center.y + scale * 0.12)
        )
        path.closeSubpath()
        return path
    }

    private func wave(y: CGFloat, size: CGSize) -> Path {
        var path = Path()
        path.move(to: point(0.04, y, size))
        for x in stride(from: CGFloat(0.10), through: CGFloat(1.00), by: CGFloat(0.16)) {
            path.addQuadCurve(to: point(x + 0.10, y, size), control: point(x, y - 0.035, size))
        }
        return path
    }

    private func leafPath(x: CGFloat, y: CGFloat, size: CGSize) -> Path {
        var path = Path()
        path.move(to: point(x, y, size))
        path.addQuadCurve(to: point(x + 0.08, y - 0.02, size), control: point(x + 0.04, y - 0.08, size))
        path.addQuadCurve(to: point(x, y, size), control: point(x + 0.03, y + 0.02, size))
        return path
    }

    private func rectPath(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ size: CGSize) -> Path {
        Path(CGRect(x: size.width * x, y: size.height * y, width: size.width * w, height: size.height * h))
    }

    private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ size: CGSize) -> CGRect {
        CGRect(x: size.width * x, y: size.height * y, width: size.width * w, height: size.height * h)
    }

    private func point(_ x: CGFloat, _ y: CGFloat, _ size: CGSize) -> CGPoint {
        CGPoint(x: size.width * x, y: size.height * y)
    }

    private func polyline(_ points: [(CGFloat, CGFloat)], _ size: CGSize) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: point(first.0, first.1, size))
        for point in points.dropFirst() {
            path.addLine(to: self.point(point.0, point.1, size))
        }
        return path
    }

    private func stroke(_ path: Path, in context: inout GraphicsContext, color: Color,
                        width: CGFloat, jitter: Bool = false) {
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        guard jitter else { return }
        context.stroke(path.applying(CGAffineTransform(translationX: width * 0.9, y: -width * 0.6)),
                       with: .color(color.opacity(0.35)),
                       style: StrokeStyle(lineWidth: width * 0.72, lineCap: .round, lineJoin: .round))
    }

    private func line(_ size: CGSize, _ scale: CGFloat) -> CGFloat {
        max(1, min(size.width, size.height) * scale)
    }
}
