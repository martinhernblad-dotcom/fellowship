import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showProfile = false

    private var displayCategories: [OursCategory] {
        viewModel.categories.isEmpty ? OursCategory.seed : viewModel.categories
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.homeBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                            .padding(.bottom, 28)

                        categoryGrid
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarHidden(true)
            .task { await viewModel.loadAll() }
            .sheet(isPresented: $showProfile) {
                ProfileSheet().environmentObject(viewModel)
            }
        }
        .tint(.white)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 2) {
                    Text("Fellowship")
                        .font(.custom("Cormorant Garamond SemiBold", size: 44))
                        .foregroundColor(Color(hex: "2A1A0E"))
                    Image(systemName: "heart")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(Color(hex: "C96E4B"))
                        .padding(.top, 8)
                }

                Group {
                    if let me = viewModel.currentProfile, let partner = viewModel.partnerProfile {
                        HStack(spacing: 6) {
                            Text("\(me.emoji) \(me.name)")
                            Text("·").foregroundColor(Color(hex: "9A8878").opacity(0.4))
                            Text("\(partner.emoji) \(partner.name)")
                        }
                    } else if let me = viewModel.currentProfile {
                        Text("\(me.emoji) \(me.name) · väntar på partner…")
                    }
                }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "9A8878"))
            }

            Spacer()

            Button { showProfile = true } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 46, height: 46)
                        .shadow(color: Color(hex: "2A1A0E").opacity(0.10), radius: 6, x: 0, y: 2)
                    Text(viewModel.currentProfile?.emoji ?? "👤")
                        .font(.system(size: 24))
                }
            }
        }
    }

    // MARK: - Grid (always 2 columns)

    private var categoryGrid: some View {
        let cats = displayCategories
        return VStack(spacing: 12) {
            ForEach(0 ..< cats.count / 2, id: \.self) { row in
                HStack(spacing: 12) {
                    categoryLink(cats[row * 2])
                    categoryLink(cats[row * 2 + 1])
                }
                .frame(height: 185)
            }
            if cats.count % 2 == 1 {
                categoryLink(cats[cats.count - 1])
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
            }
        }
    }

    private func categoryLink(_ cat: OursCategory) -> some View {
        NavigationLink { CategoryView(category: cat) } label: {
            CategoryCard(category: cat).frame(maxWidth: .infinity)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: OursCategory

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(hex: category.colorHex1), Color(hex: category.colorHex2)],
                startPoint: .top, endPoint: .bottom
            )

            ZStack {
                Image(systemName: resolvedIcon(category.iconName))
                    .font(.system(size: 68, weight: .light))
                    .foregroundStyle(Color(red: 1.0, green: 0.93, blue: 0.78).opacity(0.42))
                if let overlay = category.overlayIconName {
                    Image(systemName: overlay)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.93, blue: 0.78).opacity(0.42))
                        .offset(y: 10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .offset(y: -10)

            Text(category.name)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "F5EFE7"))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: .black.opacity(0.32), radius: 18, x: 0, y: 10)
    }

    private func resolvedIcon(_ name: String) -> String {
        let candidates = [name, name.replacingOccurrences(of: "pot", with: "cookingpot"), "fork.knife"]
        return candidates.first { UIImage(systemName: $0) != nil } ?? name
    }
}

// MARK: - Scale button style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Profile Sheet

struct ProfileSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPairing = false
    @State private var showEmojiPicker = false

    private let emojiOptions = [
        "😊", "😄", "🥰", "😎", "🤩", "🥳",
        "🦊", "🐱", "🐶", "🐸", "🦋", "🌸",
        "⭐️", "💫", "🎯", "🎨", "🎮", "🚀",
        "🌊", "🌙", "☀️", "❤️", "💚", "🍃",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    profileRow(viewModel.currentProfile, label: "Du")

                    Divider().background(Color.white.opacity(0.08))

                    if let partner = viewModel.partnerProfile {
                        profileRow(partner, label: "Partner")
                    } else {
                        pairingPrompt
                    }

                    Spacer()

                    if viewModel.coupleID != nil {
                        syncRow
                    }
                }
                .padding(24)
            }
            .navigationTitle("Profiler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Klar") { dismiss() }.foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPairing) {
            PairingView().environmentObject(viewModel)
        }
        .sheet(isPresented: $showEmojiPicker) {
            emojiPickerSheet
        }
    }

    private var emojiPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    Text(viewModel.currentProfile?.emoji ?? "😊")
                        .font(.system(size: 72))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button {
                                Task { await viewModel.updateProfileEmoji(emoji) }
                                showEmojiPicker = false
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 32))
                                    .frame(width: 52, height: 52)
                                    .background(
                                        Circle().fill(viewModel.currentProfile?.emoji == emoji
                                            ? Color.white.opacity(0.12) : Color.cardBackground)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    Spacer()
                }
                .padding(.top, 32)
            }
            .navigationTitle("Välj emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Avbryt") { showEmojiPicker = false }.foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var pairingPrompt: some View {
        Button { showPairing = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.surfaceColor).frame(width: 48, height: 48)
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "C96E4B").opacity(0.8))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Anslut partner")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Synka Fellowship med din partner")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var syncRow: some View {
        Button {
            Task { await viewModel.syncFromCloud() }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isSyncing {
                    ProgressView().tint(Color(hex: "C96E4B"))
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "C96E4B"))
                }
                Text(viewModel.isSyncing ? "Synkar…" : "Synka nu")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSyncing)
    }

    private func profileRow(_ profile: UserProfile?, label: String) -> some View {
        let isMe = profile?.deviceID == viewModel.currentProfile?.deviceID
        return HStack(spacing: 16) {
            Button {
                if isMe { showEmojiPicker = true }
            } label: {
                ZStack {
                    Circle().fill(Color.surfaceColor).frame(width: 56, height: 56)
                    Text(profile?.emoji ?? "?").font(.system(size: 30))
                    if isMe {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1.5)
                            .frame(width: 56, height: 56)
                        Image(systemName: "pencil")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(4)
                            .background(Circle().fill(Color.cardBackground))
                            .offset(x: 18, y: 18)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!isMe)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text(profile?.name ?? "—")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
        }
    }
}
