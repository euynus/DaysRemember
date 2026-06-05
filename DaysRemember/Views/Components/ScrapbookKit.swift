import SwiftUI

// Travel-scrapbook shared components — a verbatim port of `screens/Stickers.jsx`:
// flat vector stickers (white outline + drop shadow), sticky notes, paperclips,
// washi tape, and the polaroid card frame, plus the small mapping helpers.

// MARK: - Sticky-note colors

/// A sticky-note paper color paired with its matching handwriting ink.
struct NoteColor: Equatable {
    let paper: Color
    let ink: Color
}

enum ScrapbookPalette {
    /// Same order as the prototype's NOTE_COLORS array (blue, yellow, pink, green, peach).
    static let notes: [NoteColor] = [
        NoteColor(paper: Theme.noteBlue, ink: Theme.noteBlueInk),
        NoteColor(paper: Theme.noteYellow, ink: Theme.noteYellowInk),
        NoteColor(paper: Theme.notePink, ink: Theme.notePinkInk),
        NoteColor(paper: Theme.noteGreen, ink: Theme.noteGreenInk),
        NoteColor(paper: Theme.notePeach, ink: Theme.notePeachInk),
    ]

    /// Deterministic note color for an id — mirrors `noteColorFor` in Stickers.jsx.
    static func noteColor(for id: String) -> NoteColor {
        var h = 0
        for scalar in id.unicodeScalars {
            h = (h &* 31 &+ Int(scalar.value)) % notes.count
        }
        // Swift % can be negative; normalize.
        let idx = ((h % notes.count) + notes.count) % notes.count
        return notes[idx]
    }
}

/// Convenience free function matching the prototype's name.
func noteColorFor(_ id: String) -> NoteColor { ScrapbookPalette.noteColor(for: id) }

// MARK: - Stickers

enum StickerName: String, CaseIterable {
    case plane, heart, cake, balloon, ring, camera, star, sun, gift, house, paw, cap, sparkle
}

/// Per-day and per-category sticker mappings (DAY_STICKER / CAT_STICKER in the prototype).
enum StickerMap {
    static let byDayID: [String: StickerName] = [
        "wedding": .ring, "baby": .balloon, "birthday": .cake, "japan": .plane,
        "kaoyan": .cap, "firstmet": .heart, "work": .star, "dog": .paw,
        "moved": .house, "midautumn": .sparkle,
    ]
    static let byCategory: [DayCategory: StickerName] = [
        .love: .heart, .family: .balloon, .travel: .plane, .work: .star, .life: .house,
    ]
}

func stickerFor(_ day: Day) -> StickerName {
    StickerMap.byDayID[day.id] ?? StickerMap.byCategory[day.category] ?? .star
}

/// A flat vector sticker drawn in a 64×64 space, with a white outline backing and a
/// soft drop shadow (the `.sticker` filter in styles.css).
struct Sticker: View {
    let name: StickerName
    var size: CGFloat = 48
    var rotate: Double = 0

    var body: some View {
        Canvas { ctx, canvasSize in
            ctx.scaleBy(x: canvasSize.width / 64, y: canvasSize.height / 64)
            let ops = StickerOps.ops(for: name)
            // White outline backing: every op stroked white (and filled white if it's
            // an area shape), drawn first so the colored art reads on a white edge.
            for op in ops {
                if op.fill != nil {
                    ctx.fill(op.path, with: .color(.white))
                }
                ctx.stroke(op.path, with: .color(.white),
                           style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            // Colored pass.
            for op in ops {
                if let fill = op.fill {
                    ctx.fill(op.path, with: .color(fill))
                }
                if let stroke = op.stroke {
                    ctx.stroke(op.path, with: .color(stroke.color),
                               style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: 0x15171C).opacity(0.18), radius: 3, x: 0, y: 4)
        .rotationEffect(.degrees(rotate))
        .accessibilityHidden(true)
    }
}

private struct StickerOp {
    var path: Path
    var fill: Color?
    var stroke: (color: Color, width: CGFloat)?
}

private enum StickerOps {
    // Shorthand builders in the 64×64 sticker space.
    static func poly(_ pts: [(CGFloat, CGFloat)], close: Bool = true) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: CGPoint(x: first.0, y: first.1))
        for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
        if close { p.closeSubpath() }
        return p
    }
    static func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }
    static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }
    static func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    // Sticker fill/stroke colors (from Stickers.jsx).
    static let sky = Color(hex: 0x7FCBE6), skyDeep = Color(hex: 0x5BB0D0), skyInk = Color(hex: 0x2E6E88)
    static let pink = Color(hex: 0xF2778E), pinkInk = Color(hex: 0xB23E55)
    static let cakePink = Color(hex: 0xF7B7C8), cakeInk = Color(hex: 0xB05670)
    static let yellow = Color(hex: 0xFBD34D), yellowInk = Color(hex: 0x9B7A1E), yellowInk2 = Color(hex: 0xA8841E)
    static let orange = Color(hex: 0xF5A623), orangeInk = Color(hex: 0xA86A12)
    static let camera = Color(hex: 0xEF8A5A), cameraInk = Color(hex: 0xA8542C)
    static let glass = Color(hex: 0x9FE0F0), glassInk = Color(hex: 0x3A7CA0)
    static let gold = Color(hex: 0xF5C84B)
    static let terra = Color(hex: 0xE0795A)
    static let navy = Color(hex: 0x3A4254), navyInk = Color(hex: 0x1B2230)

    static func ops(for name: StickerName) -> [StickerOp] {
        switch name {
        case .plane:
            return [
                StickerOp(path: poly([(6,36),(58,18),(44,48),(35,38),(26,52),(23,37),(6,36)]),
                          fill: sky, stroke: (skyInk, 2)),
                StickerOp(path: poly([(44,48),(35,38),(44,52),(47,37)]),
                          fill: skyDeep, stroke: (skyInk, 2)),
            ]
        case .heart:
            return [StickerOp(path: heartPath(), fill: pink, stroke: (pinkInk, 2))]
        case .cake:
            var frosting = Path()
            frosting.move(to: CGPoint(x: 12, y: 40))
            frosting.addQuadCurve(to: CGPoint(x: 28, y: 40), control: CGPoint(x: 20, y: 46))
            frosting.addQuadCurve(to: CGPoint(x: 44, y: 40), control: CGPoint(x: 36, y: 34))
            frosting.addQuadCurve(to: CGPoint(x: 52, y: 40), control: CGPoint(x: 48, y: 45))
            return [
                StickerOp(path: rrect(12, 30, 40, 24, 4), fill: cakePink, stroke: (cakeInk, 2)),
                StickerOp(path: frosting, fill: nil, stroke: (cakeInk, 2)),
                StickerOp(path: rrect(30, 14, 4, 12, 2), fill: yellow, stroke: (yellowInk, 2)),
                StickerOp(path: circle(32, 12, 3), fill: pink, stroke: (pinkInk, 2)),
            ]
        case .balloon:
            var highlight = Path()
            highlight.move(to: CGPoint(x: 28, y: 18))
            highlight.addQuadCurve(to: CGPoint(x: 32, y: 14), control: CGPoint(x: 28.5, y: 15.5))
            return [
                StickerOp(path: ellipse(32, 26, 17, 20), fill: orange, stroke: (orangeInk, 2)),
                StickerOp(path: poly([(32,46),(30,54),(34,58),(32,62)], close: false),
                          fill: nil, stroke: (orangeInk, 2)),
                StickerOp(path: highlight, fill: nil, stroke: (.white, 3)),
            ]
        case .ring:
            return [
                StickerOp(path: circle(32, 38, 16), fill: nil, stroke: (gold, 6)),
                StickerOp(path: poly([(24,20),(32,10),(40,20),(32,28),(24,20)]),
                          fill: glass, stroke: (glassInk, 2)),
            ]
        case .camera:
            return [
                StickerOp(path: rrect(8, 22, 48, 32, 6), fill: camera, stroke: (cameraInk, 2)),
                StickerOp(path: poly([(22,22),(26,16),(38,16),(42,22)]), fill: camera, stroke: (cameraInk, 2)),
                StickerOp(path: circle(32, 38, 10), fill: glass, stroke: (skyInk, 2)),
                StickerOp(path: circle(32, 38, 4), fill: .white, stroke: nil),
            ]
        case .star:
            return [StickerOp(path: poly([(32,6),(40,22),(58,24),(45,37),(48,55),(32,46),(16,55),(19,37),(6,24),(24,22),(32,6)]),
                              fill: yellow, stroke: (yellowInk2, 2))]
        case .sun:
            let rays: [[(CGFloat, CGFloat)]] = [
                [(32,6),(32,14)], [(32,50),(32,58)], [(6,32),(14,32)], [(50,32),(58,32)],
                [(14,14),(19,19)], [(45,45),(50,50)], [(50,14),(45,19)], [(19,45),(14,50)],
            ]
            var ops: [StickerOp] = rays.map { StickerOp(path: poly($0, close: false), fill: nil, stroke: (yellow, 5)) }
            ops.append(StickerOp(path: circle(32, 32, 13), fill: yellow, stroke: (yellowInk2, 2)))
            return ops
        case .gift:
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: 32, y: 22)); ribbon.addLine(to: CGPoint(x: 32, y: 54))
            var bow = Path()
            bow.move(to: CGPoint(x: 32, y: 22))
            bow.addCurve(to: CGPoint(x: 22, y: 24), control1: CGPoint(x: 24, y: 10), control2: CGPoint(x: 14, y: 18))
            bow.move(to: CGPoint(x: 32, y: 22))
            bow.addCurve(to: CGPoint(x: 42, y: 24), control1: CGPoint(x: 40, y: 10), control2: CGPoint(x: 50, y: 18))
            return [
                StickerOp(path: rrect(12, 28, 40, 26, 3), fill: sky, stroke: (skyInk, 2)),
                StickerOp(path: rrect(10, 22, 44, 10, 2), fill: skyDeep, stroke: (skyInk, 2)),
                StickerOp(path: ribbon, fill: nil, stroke: (.white, 4)),
                StickerOp(path: bow, fill: pink, stroke: (pinkInk, 2)),
            ]
        case .house:
            return [
                StickerOp(path: poly([(10,30),(32,12),(54,30),(54,54),(10,54)]), fill: terra, stroke: (cameraInk, 2)),
                StickerOp(path: rrect(26, 38, 12, 16, 0), fill: glass, stroke: (skyInk, 2)),
            ]
        case .paw:
            return [
                StickerOp(path: ellipse(32, 42, 13, 11), fill: orange, stroke: (orangeInk, 2)),
                StickerOp(path: circle(18, 26, 6), fill: orange, stroke: (orangeInk, 2)),
                StickerOp(path: circle(32, 20, 6), fill: orange, stroke: (orangeInk, 2)),
                StickerOp(path: circle(46, 26, 6), fill: orange, stroke: (orangeInk, 2)),
            ]
        case .cap:
            var base = Path()
            base.move(to: CGPoint(x: 48, y: 33)); base.addLine(to: CGPoint(x: 48, y: 43))
            base.addCurve(to: CGPoint(x: 16, y: 43), control1: CGPoint(x: 48, y: 47), control2: CGPoint(x: 16, y: 47))
            base.addLine(to: CGPoint(x: 16, y: 33))
            var tassel = Path()
            tassel.move(to: CGPoint(x: 58, y: 28)); tassel.addLine(to: CGPoint(x: 58, y: 40))
            return [
                StickerOp(path: poly([(6,28),(32,18),(58,28),(32,38)]), fill: navy, stroke: (navyInk, 2)),
                StickerOp(path: base, fill: navy, stroke: (navyInk, 2)),
                StickerOp(path: tassel, fill: nil, stroke: (yellow, 3)),
                StickerOp(path: circle(58, 42, 3), fill: yellow, stroke: nil),
            ]
        case .sparkle:
            var p = Path()
            p.move(to: CGPoint(x: 32, y: 10))
            p.addCurve(to: CGPoint(x: 52, y: 32), control1: CGPoint(x: 34, y: 22), control2: CGPoint(x: 40, y: 28))
            p.addCurve(to: CGPoint(x: 32, y: 54), control1: CGPoint(x: 40, y: 36), control2: CGPoint(x: 34, y: 42))
            p.addCurve(to: CGPoint(x: 12, y: 32), control1: CGPoint(x: 30, y: 42), control2: CGPoint(x: 24, y: 36))
            p.addCurve(to: CGPoint(x: 32, y: 10), control1: CGPoint(x: 24, y: 28), control2: CGPoint(x: 30, y: 22))
            p.closeSubpath()
            return [StickerOp(path: p, fill: glass, stroke: (glassInk, 2))]
        }
    }

    static func heartPath() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 32, y: 56))
        p.addCurve(to: CGPoint(x: 8, y: 22), control1: CGPoint(x: 12, y: 42), control2: CGPoint(x: 8, y: 30))
        p.addCurve(to: CGPoint(x: 32, y: 15), control1: CGPoint(x: 8, y: 13), control2: CGPoint(x: 22, y: 11))
        p.addCurve(to: CGPoint(x: 56, y: 22), control1: CGPoint(x: 42, y: 11), control2: CGPoint(x: 56, y: 13))
        p.addCurve(to: CGPoint(x: 32, y: 56), control1: CGPoint(x: 56, y: 30), control2: CGPoint(x: 52, y: 42))
        p.closeSubpath()
        return p
    }
}

// MARK: - Paperclip

/// A wire paperclip — the SVG path from Stickers.jsx, scaled to `size`.
struct Paperclip: View {
    var size: CGFloat = 26
    var color: Color = Color(hex: 0xB9BEC6)

    var body: some View {
        Canvas { ctx, canvasSize in
            ctx.scaleBy(x: canvasSize.width / 20, y: canvasSize.height / 34)
            var p = Path()
            p.move(to: CGPoint(x: 14.5, y: 9))
            p.addLine(to: CGPoint(x: 14.5, y: 24))
            p.addCurve(to: CGPoint(x: 3.5, y: 24), control1: CGPoint(x: 14.5, y: 27.04), control2: CGPoint(x: 3.5, y: 27.04))
            p.addLine(to: CGPoint(x: 3.5, y: 7.5))
            p.addCurve(to: CGPoint(x: 10.5, y: 7.5), control1: CGPoint(x: 3.5, y: 3.6), control2: CGPoint(x: 10.5, y: 3.6))
            p.addLine(to: CGPoint(x: 10.5, y: 22))
            p.addCurve(to: CGPoint(x: 7.3, y: 22), control1: CGPoint(x: 10.5, y: 23.6), control2: CGPoint(x: 7.3, y: 23.6))
            p.addLine(to: CGPoint(x: 7.3, y: 9))
            ctx.stroke(p, with: .color(color),
                       style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size * 1.7)
        .accessibilityHidden(true)
    }
}

// MARK: - Sticky note

enum StickyNoteSize { case s, m, l }

/// A handwritten sticky note, optionally clipped on top with a paperclip.
/// Children supply their own text (counts use explicit sans + `.monospacedDigit()`).
struct StickyNote<Content: View>: View {
    var color: Color = Theme.noteBlue
    var ink: Color = Theme.noteBlueInk
    var rotate: Double = -3
    var clip: Bool = false
    var size: StickyNoteSize = .m
    @ViewBuilder var content: () -> Content

    private var pad: (CGFloat, CGFloat) {
        switch size {
        case .s: return (10, 8)
        case .m: return (12, 10)
        case .l: return (16, 14)
        }
    }
    private var fontSize: CGFloat {
        switch size {
        case .s: return 18
        case .l: return 30
        case .m: return 22
        }
    }

    var body: some View {
        content()
            .font(Theme.handCN(fontSize))
            .foregroundStyle(ink)
            .padding(.horizontal, pad.0)
            .padding(.vertical, pad.1)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color)
            )
            .shadow(color: Color(hex: 0x15171C).opacity(0.16), radius: 7, x: 0, y: 6)
            .overlay(alignment: .top) {
                if clip {
                    Paperclip().offset(y: -14)
                }
            }
            .rotationEffect(.degrees(rotate))
    }
}

// MARK: - Washi tape

/// A translucent washi-tape strip with dashed torn edges.
struct Tape: View {
    var color: Color = Color(.sRGB, red: 160/255, green: 210/255, blue: 230/255, opacity: 0.7)
    var width: CGFloat = 64

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: width, height: 22)
            .overlay(alignment: .leading) { edge }
            .overlay(alignment: .trailing) { edge }
            .shadow(color: Color(hex: 0x15171C).opacity(0.12), radius: 1.5, x: 0, y: 1)
            .accessibilityHidden(true)
    }
    private var edge: some View {
        Rectangle()
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            .foregroundStyle(Color.white.opacity(0.5))
            .frame(width: 1)
    }
}

// MARK: - Polaroid card

extension View {
    /// Wraps content in a white polaroid card: padding, 18pt corners, soft double
    /// shadow, optional rotation (the `.polaroid` class in styles.css).
    func polaroidCard(rotation: Double = 0, padding: CGFloat = 8) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white)
            )
            .compositingGroup()
            .shadow(color: Color(hex: 0x15171C).opacity(0.06), radius: 1, x: 0, y: 1)
            .shadow(color: Color(hex: 0x15171C).opacity(0.12), radius: 13, x: 0, y: 10)
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Date accent helper

/// English-style date for the handwritten accent: "03 Jun 2026".
func enDate(_ date: Date) -> String {
    let comps = CNDate.calendar.dateComponents([.year, .month, .day], from: date)
    let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    let m = months[max(0, min(11, (comps.month ?? 1) - 1))]
    let d = String(format: "%02d", comps.day ?? 1)
    return "\(d) \(m) \(comps.year ?? 2026)"
}
