import SwiftUI

// MARK: - LineCategoryIcon
//
// Cream-stroke line icons for the redesigned HomeView category tiles.
// Each icon is drawn on a 64×64 design grid and scaled via `size / 64`.
//
// Dispatches on the same `iconName` strings used by `OursCategory.iconName`
// (which currently store SF Symbol names).

struct LineCategoryIcon: View {
    let iconName: String
    var categoryName: String? = nil
    var size: CGFloat = 48
    var stroke: Color = Color(hex: "FBEDC6")

    var body: some View {
        Group {
            switch iconName {
            case "bag.fill", "bag":
                ParcelLineIcon(size: size, stroke: stroke)
            case "mountain.2.fill", "mountain":
                MountainsLineIcon(size: size, stroke: stroke)
            case "creditcard.fill", "wallet":
                ScaleLineIcon(size: size, stroke: stroke)
            case "key.fill", "key":
                PadlockLineIcon(size: size, stroke: stroke)
            case "binoculars.fill", "binoculars":
                TelescopeLineIcon(size: size, stroke: stroke)
            case "pot.fill", "pot", "cookingpot", "cookingpot.fill", "fork.knife":
                PotLineIcon(size: size, stroke: stroke)
            default:
                fallbackByName
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var fallbackByName: some View {
        switch categoryName {
        case "Shopping":     ParcelLineIcon(size: size, stroke: stroke)
        case "Resor":        MountainsLineIcon(size: size, stroke: stroke)
        case "Ekonomi":      ScaleLineIcon(size: size, stroke: stroke)
        case "Koder & Info": PadlockLineIcon(size: size, stroke: stroke)
        case "Discover":     TelescopeLineIcon(size: size, stroke: stroke)
        case "Recept":       PotLineIcon(size: size, stroke: stroke)
        default:             ParcelLineIcon(size: size, stroke: stroke)
        }
    }
}

// Shared stroke style: rounded line caps / joins, scaled width.
private func lineStyle(size: CGFloat, widthAt64: CGFloat = 1.7) -> StrokeStyle {
    StrokeStyle(lineWidth: widthAt64 * (size / 64),
                lineCap: .round,
                lineJoin: .round)
}

// MARK: - 1. Parcel

private struct ParcelLineIcon: View {
    let size: CGFloat
    let stroke: Color

    var body: some View {
        let s = size / 64
        ZStack {
            // body
            RoundedRectangle(cornerRadius: 2 * s)
                .path(in: CGRect(x: 10 * s, y: 22 * s, width: 44 * s, height: 30 * s))
                .stroke(stroke, style: lineStyle(size: size))
            // vertical seam
            Path { p in
                p.move(to: CGPoint(x: 32 * s, y: 22 * s))
                p.addLine(to: CGPoint(x: 32 * s, y: 52 * s))
            }
            .stroke(stroke, style: lineStyle(size: size))
            // bow — left loop
            Path { p in
                p.move(to: CGPoint(x: 32 * s, y: 22 * s))
                p.addQuadCurve(to: CGPoint(x: 14 * s, y: 16 * s),
                               control: CGPoint(x: 22 * s, y: 12 * s))
                p.addQuadCurve(to: CGPoint(x: 22 * s, y: 22 * s),
                               control: CGPoint(x: 12 * s, y: 22 * s))
            }
            .stroke(stroke, style: lineStyle(size: size))
            // bow — right loop (same stroke width as left)
            Path { p in
                p.move(to: CGPoint(x: 32 * s, y: 22 * s))
                p.addQuadCurve(to: CGPoint(x: 50 * s, y: 16 * s),
                               control: CGPoint(x: 42 * s, y: 12 * s))
                p.addQuadCurve(to: CGPoint(x: 42 * s, y: 22 * s),
                               control: CGPoint(x: 52 * s, y: 22 * s))
            }
            .stroke(stroke, style: lineStyle(size: size))
        }
    }
}

// MARK: - 2. Mountains

private struct MountainsLineIcon: View {
    let size: CGFloat
    let stroke: Color

    var body: some View {
        let s = size / 64
        ZStack {
            // sun
            Circle()
                .fill(stroke.opacity(0.9))
                .frame(width: 9 * s, height: 9 * s)
                .position(x: 50 * s, y: 14 * s)

            // back peak outline
            Path { p in
                p.move(to: CGPoint(x: 5 * s, y: 52 * s))
                p.addLine(to: CGPoint(x: 26 * s, y: 16 * s))
                p.addLine(to: CGPoint(x: 47 * s, y: 52 * s))
                p.closeSubpath()
            }
            .stroke(stroke, style: lineStyle(size: size))

            // back snow zigzag
            Path { p in
                p.move(to: CGPoint(x: 21 * s, y: 24 * s))
                p.addLine(to: CGPoint(x: 26 * s, y: 16 * s))
                p.addLine(to: CGPoint(x: 31 * s, y: 24 * s))
                p.addLine(to: CGPoint(x: 28 * s, y: 22 * s))
                p.addLine(to: CGPoint(x: 26 * s, y: 24 * s))
                p.addLine(to: CGPoint(x: 24 * s, y: 22 * s))
                p.closeSubpath()
            }
            .fill(stroke.opacity(0.92))

            // front peak outline
            Path { p in
                p.move(to: CGPoint(x: 31 * s, y: 52 * s))
                p.addLine(to: CGPoint(x: 44 * s, y: 30 * s))
                p.addLine(to: CGPoint(x: 57 * s, y: 52 * s))
                p.closeSubpath()
            }
            .stroke(stroke, style: lineStyle(size: size))

            // front snow zigzag
            Path { p in
                p.move(to: CGPoint(x: 40 * s, y: 36 * s))
                p.addLine(to: CGPoint(x: 44 * s, y: 30 * s))
                p.addLine(to: CGPoint(x: 48 * s, y: 36 * s))
                p.addLine(to: CGPoint(x: 46 * s, y: 34 * s))
                p.addLine(to: CGPoint(x: 44 * s, y: 36 * s))
                p.addLine(to: CGPoint(x: 42 * s, y: 34 * s))
                p.closeSubpath()
            }
            .fill(stroke.opacity(0.92))
        }
    }
}

// MARK: - 3. Scale (Ekonomi)

private struct ScaleLineIcon: View {
    let size: CGFloat
    let stroke: Color

    var body: some View {
        let s = size / 64
        let thick = lineStyle(size: size, widthAt64: 2.3)
        let thin  = lineStyle(size: size, widthAt64: 1.3)
        let base  = lineStyle(size: size)

        ZStack {
            // base bar
            Path { p in
                p.move(to: CGPoint(x: 22 * s, y: 56 * s))
                p.addLine(to: CGPoint(x: 42 * s, y: 56 * s))
            }
            .stroke(stroke, style: thick)

            // pillar
            Path { p in
                p.move(to: CGPoint(x: 32 * s, y: 56 * s))
                p.addLine(to: CGPoint(x: 32 * s, y: 22 * s))
            }
            .stroke(stroke, style: base)

            // crossbar
            Path { p in
                p.move(to: CGPoint(x: 12 * s, y: 22 * s))
                p.addLine(to: CGPoint(x: 52 * s, y: 22 * s))
            }
            .stroke(stroke, style: base)

            // chains
            Path { p in
                p.move(to: CGPoint(x: 14 * s, y: 22 * s)); p.addLine(to: CGPoint(x: 10 * s, y: 32 * s))
                p.move(to: CGPoint(x: 14 * s, y: 22 * s)); p.addLine(to: CGPoint(x: 18 * s, y: 32 * s))
                p.move(to: CGPoint(x: 50 * s, y: 22 * s)); p.addLine(to: CGPoint(x: 46 * s, y: 32 * s))
                p.move(to: CGPoint(x: 50 * s, y: 22 * s)); p.addLine(to: CGPoint(x: 54 * s, y: 32 * s))
            }
            .stroke(stroke, style: thin)

            // pans
            Path { p in
                p.move(to: CGPoint(x: 6 * s, y: 32 * s))
                p.addLine(to: CGPoint(x: 22 * s, y: 32 * s))
                p.addQuadCurve(to: CGPoint(x: 14 * s, y: 40 * s), control: CGPoint(x: 22 * s, y: 38 * s))
                p.addQuadCurve(to: CGPoint(x: 6 * s, y: 32 * s), control: CGPoint(x: 6 * s, y: 38 * s))
                p.closeSubpath()
            }
            .stroke(stroke, style: base)

            Path { p in
                p.move(to: CGPoint(x: 42 * s, y: 32 * s))
                p.addLine(to: CGPoint(x: 58 * s, y: 32 * s))
                p.addQuadCurve(to: CGPoint(x: 50 * s, y: 40 * s), control: CGPoint(x: 58 * s, y: 38 * s))
                p.addQuadCurve(to: CGPoint(x: 42 * s, y: 32 * s), control: CGPoint(x: 42 * s, y: 38 * s))
                p.closeSubpath()
            }
            .stroke(stroke, style: base)

            // pivot dot
            Circle()
                .fill(stroke)
                .frame(width: 5.2 * s, height: 5.2 * s)
                .position(x: 32 * s, y: 22 * s)

            // pointer stem + cap
            Path { p in
                p.move(to: CGPoint(x: 32 * s, y: 14 * s))
                p.addLine(to: CGPoint(x: 32 * s, y: 22 * s))
            }
            .stroke(stroke, style: base)

            Path { p in
                p.move(to: CGPoint(x: 32 * s, y: 14 * s))
                p.addLine(to: CGPoint(x: 29 * s, y: 11 * s))
                p.addLine(to: CGPoint(x: 35 * s, y: 11 * s))
                p.closeSubpath()
            }
            .fill(stroke)
        }
    }
}

// MARK: - 4. Padlock

private struct PadlockLineIcon: View {
    let size: CGFloat
    let stroke: Color

    var body: some View {
        let s = size / 64
        ZStack {
            // body
            RoundedRectangle(cornerRadius: 4 * s)
                .path(in: CGRect(x: 10 * s, y: 28 * s, width: 44 * s, height: 30 * s))
                .stroke(stroke, style: lineStyle(size: size))

            // shackle
            Path { p in
                p.move(to: CGPoint(x: 20 * s, y: 28 * s))
                p.addLine(to: CGPoint(x: 20 * s, y: 18 * s))
                p.addQuadCurve(to: CGPoint(x: 32 * s, y: 8 * s), control: CGPoint(x: 20 * s, y: 8 * s))
                p.addQuadCurve(to: CGPoint(x: 44 * s, y: 18 * s), control: CGPoint(x: 44 * s, y: 8 * s))
                p.addLine(to: CGPoint(x: 44 * s, y: 28 * s))
            }
            .stroke(stroke, style: lineStyle(size: size))

            // keyhole ring
            Circle()
                .stroke(stroke, style: lineStyle(size: size))
                .frame(width: 6.8 * s, height: 6.8 * s)
                .position(x: 32 * s, y: 40 * s)

            // keyhole slot
            Path { p in
                p.move(to: CGPoint(x: 32 * s, y: 43.4 * s))
                p.addLine(to: CGPoint(x: 32 * s, y: 50 * s))
            }
            .stroke(stroke, style: lineStyle(size: size, widthAt64: 2.3))
        }
    }
}

// MARK: - 5. Telescope (Discover)

private struct TelescopeLineIcon: View {
    let size: CGFloat
    let stroke: Color

    var body: some View {
        let s = size / 64
        ZStack {
            // rotated tube group
            ZStack {
                // tube outline
                RoundedRectangle(cornerRadius: 2 * s)
                    .path(in: CGRect(x: 12 * s, y: 20 * s, width: 40 * s, height: 12 * s))
                    .stroke(stroke, style: lineStyle(size: size))
                // tube cap (filled)
                Rectangle()
                    .path(in: CGRect(x: 12 * s, y: 20 * s, width: 6 * s, height: 12 * s))
                    .fill(stroke)
                // eyepiece
                RoundedRectangle(cornerRadius: 1 * s)
                    .path(in: CGRect(x: 46 * s, y: 18 * s, width: 8 * s, height: 16 * s))
                    .stroke(stroke, style: lineStyle(size: size))
                Circle()
                    .fill(stroke)
                    .frame(width: 5.2 * s, height: 5.2 * s)
                    .position(x: 50 * s, y: 26 * s)
            }
            .rotationEffect(.degrees(-22), anchor: UnitPoint(x: 32.0/64.0, y: 26.0/64.0))

            // tripod
            Path { p in
                p.move(to: CGPoint(x: 32 * s, y: 40 * s)); p.addLine(to: CGPoint(x: 20 * s, y: 56 * s))
                p.move(to: CGPoint(x: 32 * s, y: 40 * s)); p.addLine(to: CGPoint(x: 32 * s, y: 56 * s))
                p.move(to: CGPoint(x: 32 * s, y: 40 * s)); p.addLine(to: CGPoint(x: 44 * s, y: 56 * s))
            }
            .stroke(stroke, style: lineStyle(size: size, widthAt64: 1.9))

            // tripod hub
            Circle()
                .fill(stroke)
                .frame(width: 4.8 * s, height: 4.8 * s)
                .position(x: 32 * s, y: 40 * s)

            // sparkles
            Path { p in
                p.move(to: CGPoint(x: 12 * s, y: 12 * s))
                p.addLine(to: CGPoint(x: 13 * s, y: 14 * s))
                p.addLine(to: CGPoint(x: 15 * s, y: 15 * s))
                p.addLine(to: CGPoint(x: 13 * s, y: 16 * s))
                p.addLine(to: CGPoint(x: 12 * s, y: 18 * s))
                p.addLine(to: CGPoint(x: 11 * s, y: 16 * s))
                p.addLine(to: CGPoint(x: 9 * s, y: 15 * s))
                p.addLine(to: CGPoint(x: 11 * s, y: 14 * s))
                p.closeSubpath()
            }
            .fill(stroke)

            Path { p in
                p.move(to: CGPoint(x: 55 * s, y: 50 * s))
                p.addLine(to: CGPoint(x: 55.6 * s, y: 51.4 * s))
                p.addLine(to: CGPoint(x: 57 * s, y: 52 * s))
                p.addLine(to: CGPoint(x: 55.6 * s, y: 52.6 * s))
                p.addLine(to: CGPoint(x: 55 * s, y: 54 * s))
                p.addLine(to: CGPoint(x: 54.4 * s, y: 52.6 * s))
                p.addLine(to: CGPoint(x: 53 * s, y: 52 * s))
                p.addLine(to: CGPoint(x: 54.4 * s, y: 51.4 * s))
                p.closeSubpath()
            }
            .fill(stroke)
        }
    }
}

// MARK: - 6. Pot (Recept)

private struct PotLineIcon: View {
    let size: CGFloat
    let stroke: Color

    var body: some View {
        let s = size / 64
        ZStack {
            // ears
            Path { p in
                p.move(to: CGPoint(x: 8 * s, y: 38 * s))
                p.addQuadCurve(to: CGPoint(x: 4 * s, y: 42 * s), control: CGPoint(x: 4 * s, y: 36 * s))
                p.addQuadCurve(to: CGPoint(x: 10 * s, y: 46 * s), control: CGPoint(x: 4 * s, y: 46 * s))
            }
            .stroke(stroke, style: lineStyle(size: size))

            Path { p in
                p.move(to: CGPoint(x: 56 * s, y: 38 * s))
                p.addQuadCurve(to: CGPoint(x: 60 * s, y: 42 * s), control: CGPoint(x: 60 * s, y: 36 * s))
                p.addQuadCurve(to: CGPoint(x: 54 * s, y: 46 * s), control: CGPoint(x: 60 * s, y: 46 * s))
            }
            .stroke(stroke, style: lineStyle(size: size))

            // body
            Path { p in
                p.move(to: CGPoint(x: 10 * s, y: 36 * s))
                p.addLine(to: CGPoint(x: 54 * s, y: 36 * s))
                p.addLine(to: CGPoint(x: 52 * s, y: 54 * s))
                p.addQuadCurve(to: CGPoint(x: 48 * s, y: 58 * s), control: CGPoint(x: 52 * s, y: 58 * s))
                p.addLine(to: CGPoint(x: 16 * s, y: 58 * s))
                p.addQuadCurve(to: CGPoint(x: 12 * s, y: 54 * s), control: CGPoint(x: 12 * s, y: 58 * s))
                p.closeSubpath()
            }
            .stroke(stroke, style: lineStyle(size: size))

            // rim ellipse
            Ellipse()
                .stroke(stroke, style: lineStyle(size: size))
                .frame(width: 44 * s, height: 8 * s)
                .position(x: 32 * s, y: 36 * s)

            // belly band
            Path { p in
                p.move(to: CGPoint(x: 14 * s, y: 44 * s))
                p.addLine(to: CGPoint(x: 50 * s, y: 44 * s))
            }
            .stroke(stroke.opacity(0.55), style: lineStyle(size: size, widthAt64: 1.1))

            // steam
            Path { p in
                p.move(to: CGPoint(x: 20 * s, y: 28 * s))
                p.addQuadCurve(to: CGPoint(x: 18 * s, y: 18 * s), control: CGPoint(x: 22 * s, y: 22 * s))
                p.addQuadCurve(to: CGPoint(x: 18 * s, y: 8 * s), control: CGPoint(x: 14 * s, y: 14 * s))
            }
            .stroke(stroke, style: lineStyle(size: size))

            Path { p in
                p.move(to: CGPoint(x: 32 * s, y: 26 * s))
                p.addQuadCurve(to: CGPoint(x: 30 * s, y: 16 * s), control: CGPoint(x: 34 * s, y: 20 * s))
                p.addQuadCurve(to: CGPoint(x: 30 * s, y: 6 * s), control: CGPoint(x: 26 * s, y: 12 * s))
            }
            .stroke(stroke, style: lineStyle(size: size))

            Path { p in
                p.move(to: CGPoint(x: 44 * s, y: 28 * s))
                p.addQuadCurve(to: CGPoint(x: 42 * s, y: 18 * s), control: CGPoint(x: 46 * s, y: 22 * s))
                p.addQuadCurve(to: CGPoint(x: 42 * s, y: 8 * s), control: CGPoint(x: 38 * s, y: 14 * s))
            }
            .stroke(stroke, style: lineStyle(size: size))
        }
    }
}

#if DEBUG
struct LineCategoryIcon_Previews: PreviewProvider {
    static var previews: some View {
        let names = ["bag", "mountain", "wallet", "key", "binoculars", "pot"]
        ZStack {
            Color(hex: "A75232").ignoresSafeArea()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3),
                      spacing: 16) {
                ForEach(names, id: \.self) { name in
                    LineCategoryIcon(iconName: name, size: 64)
                }
            }
            .padding(24)
        }
    }
}
#endif
