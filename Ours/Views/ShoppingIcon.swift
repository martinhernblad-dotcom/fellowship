import SwiftUI

struct ShoppingIcon: View {
    var size: CGFloat = 64

    var body: some View {
        let s = size / 64
        ZStack {
            ShoppingShape()
                .fill(Self.clayGradient(size: size))
            Path { p in
                p.move(to: CGPoint(x: 14 * s, y: 30 * s))
                p.addLine(to: CGPoint(x: 50 * s, y: 30 * s))
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

private struct ShoppingShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        var p = Path()
        // handle (open ring)
        p.move(to: CGPoint(x: 20 * s, y: 24 * s))
        p.addQuadCurve(to: CGPoint(x: 32 * s, y: 12 * s), control: CGPoint(x: 20 * s, y: 12 * s))
        p.addQuadCurve(to: CGPoint(x: 44 * s, y: 24 * s), control: CGPoint(x: 44 * s, y: 12 * s))
        p.addLine(to: CGPoint(x: 40 * s, y: 24 * s))
        p.addQuadCurve(to: CGPoint(x: 32 * s, y: 16 * s), control: CGPoint(x: 40 * s, y: 16 * s))
        p.addQuadCurve(to: CGPoint(x: 24 * s, y: 24 * s), control: CGPoint(x: 24 * s, y: 16 * s))
        p.closeSubpath()
        // basket body
        p.move(to: CGPoint(x: 14 * s, y: 24 * s))
        p.addLine(to: CGPoint(x: 50 * s, y: 24 * s))
        p.addLine(to: CGPoint(x: 46 * s, y: 52 * s))
        p.addQuadCurve(to: CGPoint(x: 41 * s, y: 56 * s), control: CGPoint(x: 45 * s, y: 56 * s))
        p.addLine(to: CGPoint(x: 23 * s, y: 56 * s))
        p.addQuadCurve(to: CGPoint(x: 18 * s, y: 52 * s), control: CGPoint(x: 19 * s, y: 56 * s))
        p.closeSubpath()
        return p
    }
}
