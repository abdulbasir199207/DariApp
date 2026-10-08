//
//  CatMark.swift
//  DariApp
//
//  Die schwarze Katze – Markenzeichen von ZARA (eigener Entwurf, vektorgezeichnet).
//  Gleiche Geometrie wie das App-Icon und die Web-Version.
//

import SwiftUI

struct CatMark: View {

    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height) / 100
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
                var path = Path()
                path.move(to: p(points[0].0, points[0].1))
                for point in points.dropFirst() { path.addLine(to: p(point.0, point.1)) }
                path.closeSubpath()
                return path
            }
            func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: (cx - rx) * s, y: (cy - ry) * s, width: 2 * rx * s, height: 2 * ry * s))
            }
            let black = Color(red: 0.086, green: 0.094, blue: 0.106)
            let terracotta = Color(red: 0.78, green: 0.48, blue: 0.345)
            let yellow = Color(red: 0.89, green: 0.82, blue: 0.48)

            context.fill(polygon([(20, 46), (22, 14), (46, 31)]), with: .color(black))
            context.fill(polygon([(80, 46), (78, 14), (54, 31)]), with: .color(black))
            context.fill(polygon([(26, 40), (27, 22), (40, 32)]), with: .color(terracotta.opacity(0.85)))
            context.fill(polygon([(74, 40), (73, 22), (60, 32)]), with: .color(terracotta.opacity(0.85)))
            context.fill(ellipse(50, 57, 32, 27), with: .color(black))
            context.fill(ellipse(39, 54, 7, 7.6), with: .color(yellow))
            context.fill(ellipse(61, 54, 7, 7.6), with: .color(yellow))
            context.fill(ellipse(39, 54, 2, 5.6), with: .color(Color(red: 0.04, green: 0.05, blue: 0.055)))
            context.fill(ellipse(61, 54, 2, 5.6), with: .color(Color(red: 0.04, green: 0.05, blue: 0.055)))
            context.fill(ellipse(41, 51, 1.6, 1.6), with: .color(.white.opacity(0.9)))
            context.fill(ellipse(63, 51, 1.6, 1.6), with: .color(.white.opacity(0.9)))
            context.fill(polygon([(46.5, 63), (53.5, 63), (50, 67.5)]), with: .color(terracotta))

            var mouth = Path()
            mouth.move(to: p(50, 67.5)); mouth.addQuadCurve(to: p(42, 70.7), control: p(46.5, 72.5))
            mouth.move(to: p(50, 67.5)); mouth.addQuadCurve(to: p(58, 70.7), control: p(53.5, 72.5))
            context.stroke(mouth, with: .color(Color(red: 0.42, green: 0.46, blue: 0.5)),
                           style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))

            var whiskers = Path()
            for (x1, y1, x2, y2) in [(30.0, 64.0, 12.0, 61.0), (30, 68, 13, 71), (70, 64, 88, 61), (70, 68, 87, 71)] {
                whiskers.move(to: p(x1, y1)); whiskers.addLine(to: p(x2, y2))
            }
            context.stroke(whiskers, with: .color(Color(red: 0.55, green: 0.59, blue: 0.62)),
                           style: StrokeStyle(lineWidth: 1.2 * s, lineCap: .round))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#Preview {
    CatMark().frame(width: 120, height: 120).padding().background(Palette.background)
}
