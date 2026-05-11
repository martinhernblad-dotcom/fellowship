import SwiftUI

struct EkonomiIcon: View {
    var size: CGFloat = 64

    var body: some View {
        let s = size / 64
        ZStack {
            EkonomiCoinsShape()
                .fill(Self.clayGradient(size: size))
            EkonomiStarShape()
                .fill(Color(red: 50/255, green: 30/255, blue: 15/255, opacity: 0.32))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.32), radius: 1.4 * s, x: 0, y: 2.2 * s)
    }

    static func clayGradient(size: CGFloat) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 246/255, green: 229/255, blue: 198/255), location: 0.00),
                .init(color: Color(red: 231/255, green: 209/255, blue: 168/255), location: 0.55),
                .init(color: Color(red: 201/255, green: 172/255, blue: 126/255), location: 1.00)
            ]),
            center: UnitPoint(x: 0.35, y: 0.28),
            startRadius: 0,
            endRadius: size * 0.80
        )
    }
}

private struct EkonomiCoinsShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        var p = Path()
        // bottom coin band + ellipse
        p.move(to: CGPoint(x: 14 * s, y: 44 * s))
        p.addLine(to: CGPoint(x: 50 * s, y: 44 * s))
        p.addLine(to: CGPoint(x: 50 * s, y: 50 * s))
        p.addQuadCurve(to: CGPoint(x: 32 * s, y: 53 * s), control: CGPoint(x: 50 * s, y: 53 * s))
        p.addQuadCurve(to: CGPoint(x: 14 * s, y: 50 * s), control: CGPoint(x: 14 * s, y: 53 * s))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: (32 - 18) * s, y: (44 - 5) * s, width: 36 * s, height: 10 * s))
        // mid coin
        p.move(to: CGPoint(x: 15 * s, y: 33 * s))
        p.addLine(to: CGPoint(x: 49 * s, y: 33 * s))
        p.addLine(to: CGPoint(x: 49 * s, y: 39 * s))
        p.addQuadCurve(to: CGPoint(x: 32 * s, y: 42 * s), control: CGPoint(x: 49 * s, y: 42 * s))
        p.addQuadCurve(to: CGPoint(x: 15 * s, y: 39 * s), control: CGPoint(x: 15 * s, y: 42 * s))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: (32 - 17) * s, y: (33 - 5) * s, width: 34 * s, height: 10 * s))
        // top coin
        p.move(to: CGPoint(x: 16 * s, y: 22 * s))
        p.addLine(to: CGPoint(x: 48 * s, y: 22 * s))
        p.addLine(to: CGPoint(x: 48 * s, y: 28 * s))
        p.addQuadCurve(to: CGPoint(x: 32 * s, y: 31 * s), control: CGPoint(x: 48 * s, y: 31 * s))
        p.addQuadCurve(to: CGPoint(x: 16 * s, y: 28 * s), control: CGPoint(x: 16 * s, y: 31 * s))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: (32 - 16) * s, y: (22 - 5) * s, width: 32 * s, height: 10 * s))
        return p
    }
}

private struct EkonomiStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        var p = Path()
        let pts: [(CGFloat, CGFloat)] = [
            (32, 18), (33, 21), (36, 21), (33.5, 22.5), (34.5, 25),
            (32, 23.5), (29.5, 25), (30.5, 22.5), (28, 21), (31, 21)
        ]
        p.move(to: CGPoint(x: pts[0].0 * s, y: pts[0].1 * s))
        for pt in pts.dropFirst() {
            p.addLine(to: CGPoint(x: pt.0 * s, y: pt.1 * s))
        }
        p.closeSubpath()
        return p
    }
}
