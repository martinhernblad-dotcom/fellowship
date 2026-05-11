import SwiftUI

struct DiscoverIcon: View {
    var size: CGFloat = 64

    var body: some View {
        let s = size / 64
        ZStack {
            // outer disc
            Circle()
                .fill(Self.clayGradient(size: size))
                .frame(width: 44 * s, height: 44 * s)
                .position(x: 32 * s, y: 32 * s)
            // outer ring detail
            Circle()
                .stroke(Color(red: 50/255, green: 30/255, blue: 15/255, opacity: 0.25),
                        lineWidth: 1.4 * s)
                .frame(width: 44 * s, height: 44 * s)
                .position(x: 32 * s, y: 32 * s)
            // inner ring
            Circle()
                .stroke(Color(red: 50/255, green: 30/255, blue: 15/255, opacity: 0.18),
                        lineWidth: 1 * s)
                .frame(width: 32 * s, height: 32 * s)
                .position(x: 32 * s, y: 32 * s)
            // dark needle
            CompassNeedleShape()
                .fill(Color(red: 50/255, green: 30/255, blue: 15/255, opacity: 0.40))
            // north tip highlight
            CompassNorthHighlightShape()
                .fill(Color(red: 244/255, green: 226/255, blue: 188/255, opacity: 0.70))
            // center pin
            Circle()
                .fill(Color(red: 30/255, green: 18/255, blue: 10/255, opacity: 0.60))
                .frame(width: 4 * s, height: 4 * s)
                .position(x: 32 * s, y: 32 * s)
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

private struct CompassNeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        var p = Path()
        p.move(to: CGPoint(x: 32 * s, y: 14 * s))
        p.addLine(to: CGPoint(x: 36 * s, y: 32 * s))
        p.addLine(to: CGPoint(x: 32 * s, y: 50 * s))
        p.addLine(to: CGPoint(x: 28 * s, y: 32 * s))
        p.closeSubpath()
        return p
    }
}

private struct CompassNorthHighlightShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 64
        var p = Path()
        p.move(to: CGPoint(x: 32 * s, y: 14 * s))
        p.addLine(to: CGPoint(x: 34 * s, y: 24 * s))
        p.addLine(to: CGPoint(x: 30 * s, y: 24 * s))
        p.closeSubpath()
        return p
    }
}
