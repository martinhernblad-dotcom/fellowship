import SwiftUI

struct ReceptIcon: View {
    var size: CGFloat = 64

    var body: some View {
        let s = size / 64
        ZStack {
            // steam wisps
            SteamWispsShape()
                .stroke(Color(red: 244/255, green: 226/255, blue: 188/255, opacity: 0.55),
                        style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
            // pot body + handles
            PotShape()
                .fill(Self.clayGradient(size: size))
            // rim detail
            Path { p in
                p.move(to: CGPoint(x: 14 * s, y: 34 * s))
                p.addLine(to: CGPoint(x: 50 * s, y: 34 * s))
            }
            .stroke(Color(red: 50/255, green: 30/255, blue: 15/255, opacity: 0.25),
                    style: StrokeStyle(lineWidth: 1.4 * s, lineCap: .round))
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

private struct PotShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        var p = Path()
        // left handle knob
        p.move(to: CGPoint(x: 8 * s, y: 32 * s))
        p.addQuadCurve(to: CGPoint(x: 6 * s, y: 36 * s), control: CGPoint(x: 6 * s, y: 32 * s))
        p.addQuadCurve(to: CGPoint(x: 8 * s, y: 40 * s), control: CGPoint(x: 6 * s, y: 40 * s))
        p.addLine(to: CGPoint(x: 12 * s, y: 40 * s))
        p.addLine(to: CGPoint(x: 12 * s, y: 32 * s))
        p.closeSubpath()
        // right handle knob
        p.move(to: CGPoint(x: 52 * s, y: 32 * s))
        p.addLine(to: CGPoint(x: 52 * s, y: 40 * s))
        p.addLine(to: CGPoint(x: 56 * s, y: 40 * s))
        p.addQuadCurve(to: CGPoint(x: 58 * s, y: 36 * s), control: CGPoint(x: 58 * s, y: 40 * s))
        p.addQuadCurve(to: CGPoint(x: 56 * s, y: 32 * s), control: CGPoint(x: 58 * s, y: 32 * s))
        p.closeSubpath()
        // pot body
        p.move(to: CGPoint(x: 12 * s, y: 30 * s))
        p.addQuadCurve(to: CGPoint(x: 14 * s, y: 28 * s), control: CGPoint(x: 12 * s, y: 28 * s))
        p.addLine(to: CGPoint(x: 50 * s, y: 28 * s))
        p.addQuadCurve(to: CGPoint(x: 52 * s, y: 30 * s), control: CGPoint(x: 52 * s, y: 28 * s))
        p.addLine(to: CGPoint(x: 52 * s, y: 46 * s))
        p.addQuadCurve(to: CGPoint(x: 44 * s, y: 54 * s), control: CGPoint(x: 52 * s, y: 54 * s))
        p.addLine(to: CGPoint(x: 20 * s, y: 54 * s))
        p.addQuadCurve(to: CGPoint(x: 12 * s, y: 46 * s), control: CGPoint(x: 12 * s, y: 54 * s))
        p.closeSubpath()
        return p
    }
}

private struct SteamWispsShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        var p = Path()
        // wisp 1
        p.move(to: CGPoint(x: 24 * s, y: 22 * s))
        p.addQuadCurve(to: CGPoint(x: 24 * s, y: 12 * s), control: CGPoint(x: 26 * s, y: 16 * s))
        // wisp 2
        p.move(to: CGPoint(x: 32 * s, y: 22 * s))
        p.addQuadCurve(to: CGPoint(x: 32 * s, y: 12 * s), control: CGPoint(x: 34 * s, y: 16 * s))
        // wisp 3
        p.move(to: CGPoint(x: 40 * s, y: 22 * s))
        p.addQuadCurve(to: CGPoint(x: 40 * s, y: 12 * s), control: CGPoint(x: 42 * s, y: 16 * s))
        return p
    }
}
