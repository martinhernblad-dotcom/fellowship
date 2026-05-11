import SwiftUI

struct KoderIcon: View {
    var size: CGFloat = 64

    var body: some View {
        let s = size / 64
        ZStack {
            PadlockShape()
                .fill(Self.clayGradient(size: size))
            KeyholeShape()
                .fill(Color(red: 50/255, green: 30/255, blue: 15/255, opacity: 0.42))
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

private struct PadlockShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        var p = Path()
        // shackle
        p.move(to: CGPoint(x: 22 * s, y: 30 * s))
        p.addLine(to: CGPoint(x: 22 * s, y: 20 * s))
        p.addQuadCurve(to: CGPoint(x: 32 * s, y: 10 * s), control: CGPoint(x: 22 * s, y: 10 * s))
        p.addQuadCurve(to: CGPoint(x: 42 * s, y: 20 * s), control: CGPoint(x: 42 * s, y: 10 * s))
        p.addLine(to: CGPoint(x: 42 * s, y: 30 * s))
        p.addLine(to: CGPoint(x: 38 * s, y: 30 * s))
        p.addLine(to: CGPoint(x: 38 * s, y: 20 * s))
        p.addQuadCurve(to: CGPoint(x: 32 * s, y: 14 * s), control: CGPoint(x: 38 * s, y: 14 * s))
        p.addQuadCurve(to: CGPoint(x: 26 * s, y: 20 * s), control: CGPoint(x: 26 * s, y: 14 * s))
        p.addLine(to: CGPoint(x: 26 * s, y: 30 * s))
        p.closeSubpath()
        // body
        p.move(to: CGPoint(x: 14 * s, y: 28 * s))
        p.addQuadCurve(to: CGPoint(x: 16 * s, y: 26 * s), control: CGPoint(x: 14 * s, y: 26 * s))
        p.addLine(to: CGPoint(x: 48 * s, y: 26 * s))
        p.addQuadCurve(to: CGPoint(x: 50 * s, y: 28 * s), control: CGPoint(x: 50 * s, y: 26 * s))
        p.addLine(to: CGPoint(x: 50 * s, y: 52 * s))
        p.addQuadCurve(to: CGPoint(x: 48 * s, y: 54 * s), control: CGPoint(x: 50 * s, y: 54 * s))
        p.addLine(to: CGPoint(x: 16 * s, y: 54 * s))
        p.addQuadCurve(to: CGPoint(x: 14 * s, y: 52 * s), control: CGPoint(x: 14 * s, y: 54 * s))
        p.closeSubpath()
        return p
    }
}

private struct KeyholeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        var p = Path()
        p.addEllipse(in: CGRect(x: (32 - 3) * s, y: (38 - 3) * s, width: 6 * s, height: 6 * s))
        p.addRect(CGRect(x: 30.5 * s, y: 38 * s, width: 3 * s, height: 8 * s))
        return p
    }
}
