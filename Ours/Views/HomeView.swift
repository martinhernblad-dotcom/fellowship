import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showProfile = false

    private var displayCategories: [OursCategory] {
        viewModel.categories.isEmpty ? OursCategory.seed : viewModel.categories
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

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
                Text("Fellowship")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Group {
                    if let me = viewModel.currentProfile, let partner = viewModel.partnerProfile {
                        HStack(spacing: 4) {
                            Text("\(me.emoji) \(me.name)")
                            Text("&").foregroundColor(.white.opacity(0.3))
                            Text("\(partner.emoji) \(partner.name)")
                        }
                    } else if let me = viewModel.currentProfile {
                        Text("\(me.emoji) \(me.name) · väntar på partner…")
                    }
                }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            Button { showProfile = true } label: {
                ZStack {
                    Circle()
                        .fill(Color.surfaceColor)
                        .frame(width: 46, height: 46)
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
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Soft glow blob
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 140)
                .blur(radius: 28)
                .offset(x: -28, y: -28)

            // Centered artwork — SF Symbol for Ekonomi/Discover, illustration for others
            Group {
                if category.useSystemIcon {
                    Image(systemName: category.iconName)
                        .font(.system(size: 80, weight: .thin))
                        .foregroundColor(.white)
                } else {
                    Image(category.artImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 112)
                }
            }
            .opacity(0.22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .offset(y: -14)

            // Name bottom-left
            Text(category.name)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color(hex: category.colorHex1).opacity(0.28), radius: 14, x: 0, y: 6)
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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    profileRow(viewModel.currentProfile, label: "Du")
                    if let partner = viewModel.partnerProfile {
                        Divider().background(Color.white.opacity(0.08))
                        profileRow(partner, label: "Partner")
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 38))
                                .foregroundColor(.white.opacity(0.25))
                            Text("Partner har inte anslutit än")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                            Text("De syns här när de öppnar appen.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.white.opacity(0.25))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 16)
                    }
                    Spacer()
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
    }

    private func profileRow(_ profile: UserProfile?, label: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.surfaceColor).frame(width: 56, height: 56)
                Text(profile?.emoji ?? "?").font(.system(size: 30))
            }
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
