import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    @State private var name          = ""
    @State private var selectedEmoji = "😊"
    @State private var isLoading     = false

    private let emojiOptions = [
        "😊", "😄", "🥰", "😎", "🤩", "🥳",
        "🦊", "🐱", "🐶", "🐸", "🦋", "🌸",
        "⭐️", "💫", "🎯", "🎨", "🎮", "🚀",
        "🌊", "🌙", "☀️", "❤️", "💚", "🍃",
    ]

    // Warm Fellowship gradient
    private let gradientColors = [Color(hex: "C9643A"), Color(hex: "3E7D5E")]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea(.container)

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 10) {
                    Text("Välkommen till")
                        .font(.system(size: 19, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))

                    Text("Fellowship")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading, endPoint: .trailing))

                    Text("Er gemensamma plats")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.white.opacity(0.38))
                }

                Spacer().frame(height: 44)

                // Avatar preview
                ZStack {
                    Circle()
                        .fill(Color.cardBackground)
                        .frame(width: 96, height: 96)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                    Text(selectedEmoji).font(.system(size: 52))
                }

                Spacer().frame(height: 20)

                // Emoji picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button { selectedEmoji = emoji } label: {
                                Text(emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 52, height: 52)
                                    .background(Circle().fill(
                                        selectedEmoji == emoji
                                            ? Color.white.opacity(0.12)
                                            : Color.cardBackground
                                    ))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer().frame(height: 32)

                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("DITT NAMN")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(1.2)
                        .padding(.horizontal, 24)

                    TextField("", text: $name,
                              prompt: Text("Skriv ditt namn").foregroundColor(.white.opacity(0.28)))
                        .font(.system(size: 18, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                        .padding(.horizontal, 24)
                }

                Spacer().frame(height: 36)

                // CTA
                Button {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !isLoading else { return }
                    isLoading = true
                    Task { await viewModel.setupProfile(name: trimmed, emoji: selectedEmoji) }
                } label: {
                    HStack(spacing: 10) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Kom igång")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: name.trimmingCharacters(in: .whitespaces).isEmpty
                                ? [Color.surfaceColor, Color.surfaceColor]
                                : gradientColors,
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                .animation(.easeInOut(duration: 0.2), value: name.isEmpty)

                Spacer().frame(height: 48)
            }
        }
    }
}
