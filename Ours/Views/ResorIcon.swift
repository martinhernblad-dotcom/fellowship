import SwiftUI

struct ResorIcon: View {
    var size: CGFloat = 64

    var body: some View {
        let s = size / 64
        ResorShape()
            .fill(Self.clayGradient(size: size))
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

private struct ResorShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        var p = Path()
        // moon
        p.addEllipse(in: CGRect(x: (48 - 3.5) * s, y: (16 - 3.5) * s, width: 7 * s, height: 7 * s))
        // left peak
        p.move(to: CGPoint(x: 8 * s, y: 50 * s))
        p.addLine(to: CGPoint(x: 20 * s, y: 30 * s))
        p.addLine(to: CGPoint(x: 32 * s, y: 50 * s))
        p.closeSubpath()
        // tall middle peak
        p.move(to: CGPoint(x: 18 * s, y: 50 * s))
        p.addLine(to: CGPoint(x: 32 * s, y: 16 * s))
        p.addLine(to: CGPoint(x: 46 * s, y: 50 * s))
        p.closeSubpath()
        // right peak
        p.move(to: CGPoint(x: 32 * s, y: 50 * s))
        p.addLine(to: CGPoint(x: 46 * s, y: 28 * s))
        p.addLine(to: CGPoint(x: 58 * s, y: 50 * s))
        p.closeSubpath()
        return p
    }
}
