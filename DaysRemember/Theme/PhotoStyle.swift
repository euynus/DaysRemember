import SwiftUI

/// One of the prototype's CSS `.photo-*` gradient classes.
enum PhotoStyle: String, Codable, CaseIterable, Hashable {
    case wedding, baby, birthday, japan, study, memorial, work, pet, home, health
    case sketchMountain, sketchSea, sketchCafe, sketchGarden

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
        case .sketchMountain: return "手绘山野"
        case .sketchSea: return "手绘海边"
        case .sketchCafe: return "手绘咖啡"
        case .sketchGarden: return "手绘花园"
        }
    }

    /// Background gradient — matches the corresponding rule in `styles.css`.
    @ViewBuilder
    func background() -> some View {
        switch self {
        case .wedding:
            // radial-gradient(circle at 30% 40%, oklch(0.88 0.05 60) → oklch(0.78 0.09 45) → oklch(0.55 0.09 30))
            RadialGradient(
                colors: [Color(oklch: 0.88, 0.05, 60),
                         Color(oklch: 0.78, 0.09, 45),
                         Color(oklch: 0.55, 0.09, 30)],
                center: UnitPoint(x: 0.30, y: 0.40),
                startRadius: 0, endRadius: 280)
        case .baby:
            RadialGradient(
                colors: [Color(oklch: 0.93, 0.04, 25),
                         Color(oklch: 0.82, 0.07, 20),
                         Color(oklch: 0.65, 0.09, 15)],
                center: UnitPoint(x: 0.70, y: 0.30),
                startRadius: 0, endRadius: 280)
        case .birthday:
            RadialGradient(
                colors: [Color(oklch: 0.88, 0.12, 70),
                         Color(oklch: 0.68, 0.15, 45),
                         Color(oklch: 0.35, 0.10, 25)],
                center: UnitPoint(x: 0.50, y: 0.70),
                startRadius: 0, endRadius: 320)
        case .japan:
            LinearGradient(
                colors: [Color(oklch: 0.78, 0.08, 10),
                         Color(oklch: 0.55, 0.10, 260),
                         Color(oklch: 0.32, 0.08, 270)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .study:
            LinearGradient(
                colors: [Color(oklch: 0.40, 0.08, 250),
                         Color(oklch: 0.25, 0.06, 255)],
                startPoint: .top, endPoint: .bottom)
        case .memorial:
            LinearGradient(
                colors: [Color(oklch: 0.70, 0.02, 230),
                         Color(oklch: 0.45, 0.02, 230)],
                startPoint: .top, endPoint: .bottom)
        case .work:
            LinearGradient(
                colors: [Color(oklch: 0.78, 0.05, 150),
                         Color(oklch: 0.50, 0.07, 155)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pet:
            LinearGradient(
                colors: [Color(oklch: 0.85, 0.06, 70),
                         Color(oklch: 0.55, 0.08, 50)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .home:
            LinearGradient(
                colors: [Color(oklch: 0.82, 0.04, 55),
                         Color(oklch: 0.48, 0.06, 30)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .health:
            LinearGradient(
                colors: [Color(oklch: 0.80, 0.09, 140),
                         Color(oklch: 0.45, 0.08, 150)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sketchMountain:
            HandDrawnPhotoBackground(scene: .mountain)
        case .sketchSea:
            HandDrawnPhotoBackground(scene: .sea)
        case .sketchCafe:
            HandDrawnPhotoBackground(scene: .cafe)
        case .sketchGarden:
            HandDrawnPhotoBackground(scene: .garden)
        }
    }
}

private enum HandDrawnScene {
    case mountain, sea, cafe, garden
}

private struct HandDrawnPhotoBackground: View {
    let scene: HandDrawnScene

    var body: some View {
        ZStack {
            LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                switch scene {
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
