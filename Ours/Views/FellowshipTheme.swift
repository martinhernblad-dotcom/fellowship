import SwiftUI

enum HearthTheme {
    static let bg          = Color(hex: 0x1F1813)
    static let bgSheet     = Color(hex: 0x2A201A)
    static let cream       = Color(hex: 0xF4E2BC)
    static let creamHi     = Color(hex: 0xFAF1DD)
    static let cream65     = Color(hex: 0xF4E2BC, alpha: 0.65)
    static let cream55     = Color(hex: 0xF4E2BC, alpha: 0.55)
    static let cream40     = Color(hex: 0xF4E2BC, alpha: 0.40)
    static let cream25     = Color(hex: 0xF4E2BC, alpha: 0.25)
    static let cream18     = Color(hex: 0xF4E2BC, alpha: 0.18)
    static let cream14     = Color(hex: 0xF4E2BC, alpha: 0.14)
    static let cream08     = Color(hex: 0xF4E2BC, alpha: 0.08)
    static let cream05     = Color(hex: 0xF4E2BC, alpha: 0.05)
    static let inkShadow   = Color(hex: 0x140C06, alpha: 0.30)

    static let serifTitle  = "Cormorant Garamond Medium"
    static let serifBody   = "Cormorant Garamond SemiBold"
    static let mono        = "JetBrainsMono-Regular"
}

struct HearthBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            HearthTheme.bg.ignoresSafeArea()
            RadialGradient(
                gradient: Gradient(colors: [Color(hex: 0xC96E4B, alpha: 0.18), .clear]),
                center: UnitPoint(x: 0.30, y: 0.0),
                startRadius: 0,
                endRadius: 380
            )
            .frame(height: 380)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .top)
        }
    }
}

struct HearthOrnament: View {
    var width: CGFloat = 200
    var body: some View {
        HStack(spacing: 10) {
            rule
            Rectangle()
                .fill(Color(hex: 0xF4E2BC, alpha: 0.6))
                .frame(width: 5, height: 5)
                .rotationEffect(.degrees(45))
            rule
        }
        .frame(width: width)
    }
    private var rule: some View {
        LinearGradient(
            colors: [.clear, Color(hex: 0xF4E2BC, alpha: 0.45), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }
}

struct HearthNavBar: View {
    var backLabel: String = "Hem"
    var chapter: String? = nil
    var trailingTitle: String? = nil
    var onBack: () -> Void = {}
    var onTrailing: () -> Void = {}

    var body: some View {
        HStack(alignment: .center) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text(backLabel)
                        .font(.custom(HearthTheme.serifBody, size: 16))
                }
                .foregroundColor(HearthTheme.cream)
            }
            .buttonStyle(.plain)

            Spacer()

            if let chapter {
                Text(chapter)
                    .font(.custom(HearthTheme.mono, size: 9))
                    .kerning(2)
                    .foregroundColor(HearthTheme.cream55)
            }

            Spacer()

            if let trailingTitle {
                Button(action: onTrailing) {
                    HStack(spacing: 6) {
                        Text("+").font(.system(size: 14, weight: .regular))
                        Text(trailingTitle)
                            .font(.custom(HearthTheme.serifBody, size: 14))
                    }
                    .foregroundColor(HearthTheme.cream)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(
                        Capsule().stroke(HearthTheme.cream25, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }
}

struct HearthMasthead: View {
    var kicker: String
    var title: String
    var subtitle: String?
    var body: some View {
        VStack(spacing: 0) {
            Text(kicker)
                .font(.custom(HearthTheme.mono, size: 9))
                .kerning(2)
                .foregroundColor(HearthTheme.cream55)
            Text(title)
                .font(.custom(HearthTheme.serifTitle, size: 46))
                .foregroundColor(HearthTheme.cream)
                .padding(.top, 6)
            if let subtitle {
                Text("— \(subtitle) —")
                    .font(.custom(HearthTheme.serifBody, size: 14))
                    .foregroundColor(HearthTheme.cream65)
                    .padding(.top, 4)
            }
            HearthOrnament(width: 200)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }
}

struct HearthBottomNav: View {
    var items: [String] = ["✦ Hem", "Listor", "Vi"]
    var selectedIndex: Int = 1
    var body: some View {
        HStack(spacing: 22) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, label in
                Text(label)
                    .font(.custom(HearthTheme.serifBody, size: 14))
                    .foregroundColor(HearthTheme.cream)
                    .opacity(i == selectedIndex ? 1.0 : 0.55)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(Color(hex: 0x1F1813, alpha: 0.85))
        )
        .overlay(
            Capsule().stroke(HearthTheme.cream18, lineWidth: 1)
        )
    }
}

struct HearthPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
