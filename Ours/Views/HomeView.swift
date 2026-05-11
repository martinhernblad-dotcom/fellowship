import SwiftUI
import UIKit

// MARK: - Hearth accent overrides per category name
private let hearthAccents: [String: (String, String)] = [
    "Shopping":    ("C96E4B", "A75232"),
    "Resor":       ("8E8A5E", "6F6B47"),
    "Ekonomi":     ("C9893A", "A56F25"),
    "Koder & Info":("6F6B47", "544F33"),
    "Discover":    ("B49A78", "9A7E5A"),
    "Recept":      ("B85838", "8B3D22"),
]

private func hearthAccent1(_ cat: OursCategory) -> Color {
    Color(hex: hearthAccents[cat.name]?.0 ?? cat.colorHex1)
}
private func hearthAccent2(_ cat: OursCategory) -> Color {
    Color(hex: hearthAccents[cat.name]?.1 ?? cat.colorHex2)
}

// Cream used for line icons / rule / label on tiles.
private let tileInk = Color(hex: "FBEDC6")

// MARK: - Season helper
private func currentSeasonRibbon() -> String {
    let cal = Calendar.current
    let week = cal.component(.weekOfYear, from: Date())
    let month = cal.component(.month, from: Date())
    let season: String
    switch month {
    case 3...5:  season = "Vår"
    case 6...8:  season = "Sommar"
    case 9...11: season = "Höst"
    default:     season = "Vinter"
    }
    return "\(season.uppercased()) · VECKA \(week)"
}

struct HomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showProfile = false
    @State private var searchText = ""

    private var displayCategories: [OursCategory] {
        viewModel.categories.isEmpty ? OursCategory.seed : viewModel.categories
    }

    private var searchResults: [(OursCategory, OursSubcategory)] {
        guard !searchText.isEmpty else { return [] }
        let q = searchText.lowercased()
        return displayCategories.flatMap { cat in
            (viewModel.subcategoriesByCategory[cat.id] ?? [])
                .filter { $0.name.lowercased().contains(q) }
                .map { (cat, $0) }
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 11),
        GridItem(.flexible(), spacing: 11)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(hex: "1F1813").ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [Color(hex: "C96E4B").opacity(0.22), .clear]),
                    center: UnitPoint(x: 0.30, y: 0.0),
                    startRadius: 0,
                    endRadius: 380
                )
                .frame(height: 380)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.top, 16)

                        coupleStrip
                            .padding(.top, 6)

                        seasonRibbon
                            .padding(.top, 14)

                        searchBar
                            .padding(.top, 12)

                        if searchText.isEmpty {
                            LazyVGrid(columns: columns, spacing: 11) {
                                ForEach(displayCategories) { cat in
                                    categoryLink(cat)
                                }
                            }
                            .padding(.top, 14)

                            Text(relativeSyncLabel)
                                .font(.custom("JetBrainsMono-Regular", size: 11))
                                .kerning(1.0)
                                .foregroundColor(Color(hex: "F2E4CB").opacity(0.35))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 14)
                                .padding(.bottom, 16)
                        } else {
                            searchResultsList
                                .padding(.top, 14)
                                .padding(.bottom, 40)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .scrollDisabled(searchText.isEmpty)
            }
            .navigationBarHidden(true)
            .task { await viewModel.loadAll() }
            .onChange(of: searchText) { _, text in
                if !text.isEmpty { Task { await viewModel.loadAllSubcategories() } }
            }
            .sheet(isPresented: $showProfile) {
                ProfileSheet().environmentObject(viewModel)
            }
        }
        .tint(.white)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(alignment: .top, spacing: 2) {
                Text("Fellowship")
                    .font(.custom("Cormorant Garamond Medium", size: 46))
                    .kerning(-0.5)
                    .foregroundColor(Color(hex: "F2E4CB"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                // Warm rose-red filled heart, symmetric and upright.
                FellowshipHeart()
                    .fill(Color(hex: "C4625A"))
                    .frame(width: 15, height: 14)
                    .padding(.top, 14)
            }

            Spacer(minLength: 0)

            Button { showProfile = true } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: "36281D"))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Color(hex: "F2E4CB").opacity(0.10), lineWidth: 1))
                    Text(viewModel.currentProfile?.emoji ?? "👤")
                        .font(.system(size: 22))
                }
            }
        }
    }

    // MARK: - Couple strip

    @ViewBuilder
    private var coupleStrip: some View {
        if let me = viewModel.currentProfile, let partner = viewModel.partnerProfile {
            HStack(spacing: 8) {
                Text("\(me.emoji) \(me.name)")
                    .font(.custom("Cormorant Garamond Medium", size: 14))
                    .foregroundColor(Color(hex: "F2E4CB").opacity(0.55))
                Rectangle()
                    .fill(Color(hex: "F2E4CB").opacity(0.25))
                    .frame(width: 14, height: 1)
                Text("\(partner.emoji) \(partner.name)")
                    .font(.custom("Cormorant Garamond Medium", size: 14))
                    .foregroundColor(Color(hex: "F2E4CB").opacity(0.55))
            }
        } else if let me = viewModel.currentProfile {
            Text("\(me.emoji) \(me.name) · väntar på partner…")
                .font(.custom("Cormorant Garamond Medium", size: 14))
                .foregroundColor(Color(hex: "F2E4CB").opacity(0.55))
        }
    }

    // MARK: - Season ribbon

    private var seasonRibbon: some View {
        HStack(spacing: 12) {
            ribbonRule
            Text(currentSeasonRibbon())
                .font(.custom("JetBrainsMono-Regular", size: 10))
                .kerning(2.0)
                .foregroundColor(Color(hex: "F2E4CB").opacity(0.55))
                .fixedSize()
            ribbonRule
        }
    }

    private var ribbonRule: some View {
        LinearGradient(
            colors: [.clear, Color(hex: "F2E4CB").opacity(0.20), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "F2E4CB").opacity(0.30))
            TextField("", text: $searchText,
                      prompt: Text("Sök i Fellowship…")
                          .foregroundColor(Color(hex: "F2E4CB").opacity(0.28)))
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(Color(hex: "F2E4CB").opacity(0.80))
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(hex: "F2E4CB").opacity(0.30))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(hex: "F2E4CB").opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color(hex: "F2E4CB").opacity(0.10), lineWidth: 1))
    }

    // MARK: - Search results

    @ViewBuilder
    private var searchResultsList: some View {
        if searchResults.isEmpty {
            Text("Inga resultat för \"\(searchText)\"")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(Color(hex: "F2E4CB").opacity(0.40))
                .padding(.top, 8)
        } else {
            VStack(spacing: 8) {
                ForEach(searchResults, id: \.1.id) { cat, sub in
                    searchResultRow(cat: cat, sub: sub)
                }
            }
        }
    }

    private func searchResultRow(cat: OursCategory, sub: OursSubcategory) -> some View {
        NavigationLink {
            if cat.useTripView {
                TripDetailView(trip: sub, category: cat).environmentObject(viewModel)
            } else if cat.useEkonomiView {
                TripDetailView(trip: sub, category: cat).environmentObject(viewModel)
            } else {
                SubcategoryView(subcategory: sub, category: cat).environmentObject(viewModel)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [hearthAccent1(cat), hearthAccent2(cat)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Image(systemName: sub.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "FAF1DD").opacity(0.85))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(sub.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "F2E4CB"))
                    Text(cat.name)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color(hex: "F2E4CB").opacity(0.45))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "F2E4CB").opacity(0.25))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(hex: "36281D").opacity(0.80))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(hex: "F2E4CB").opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(HomeTilePressStyle())
        .simultaneousGesture(TapGesture().onEnded { clearSearch() })
    }

    private func clearSearch() {
        searchText = ""
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - Category tile

    private func categoryLink(_ cat: OursCategory) -> some View {
        NavigationLink {
            if cat.useEkonomiView {
                EkonomiView(category: cat).environmentObject(viewModel)
            } else {
                CategoryView(category: cat).environmentObject(viewModel)
            }
        } label: {
            HearthTile(category: cat)
        }
        .buttonStyle(HomeTilePressStyle())
    }

    // MARK: - Sync footer

    private var relativeSyncLabel: String {
        guard let last = viewModel.lastSyncDate else { return "SYNKAT · ALDRIG" }
        let minutes = Int(-last.timeIntervalSinceNow / 60)
        if minutes < 1 { return "SYNKAT · JUST NU" }
        if minutes == 1 { return "SYNKAT · 1 MIN SEDAN" }
        if minutes < 60 { return "SYNKAT · \(minutes) MIN SEDAN" }
        let hours = minutes / 60
        return "SYNKAT · \(hours) TIM SEDAN"
    }
}

// MARK: - Hearth Tile (T · Field with rule)

struct HearthTile: View {
    let category: OursCategory

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [hearthAccent1(category), hearthAccent2(category)],
                startPoint: .top,
                endPoint:   .bottom
            )

            VStack(spacing: 7) {
                LineCategoryIcon(iconName: category.iconName,
                                 categoryName: category.name,
                                 size: 48,
                                 stroke: tileInk)

                // hairline rule with centre dot
                HStack(spacing: 5) {
                    Rectangle().fill(tileInk).frame(width: 18, height: 1)
                    Circle().fill(tileInk).frame(width: 2, height: 2)
                    Rectangle().fill(tileInk).frame(width: 18, height: 1)
                }
                .opacity(0.7)

                Text(category.name)
                    .font(.custom("Cormorant Garamond Medium", size: 19))
                    .kerning(-0.2)
                    .foregroundColor(tileInk)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .shadow(color: Color(hex: "140C06").opacity(0.25), radius: 0, x: 0, y: 1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "140804").opacity(0.32), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .inset(by: 0.5)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
    }
}

// MARK: - Heart shape

/// Symmetric filled heart used beside the "Fellowship" title.
/// Classic two-lobe heart, mirrored across the vertical axis.
struct FellowshipHeart: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let midX = rect.midX
        let topDip = rect.minY + h * 0.28

        var p = Path()
        p.move(to: CGPoint(x: midX, y: topDip))
        // Left lobe down to bottom tip
        p.addCurve(
            to: CGPoint(x: midX, y: rect.maxY),
            control1: CGPoint(x: rect.minX - w * 0.10, y: rect.minY - h * 0.10),
            control2: CGPoint(x: rect.minX - w * 0.05, y: rect.minY + h * 0.55)
        )
        // Right lobe back up to top dip (mirror of left)
        p.addCurve(
            to: CGPoint(x: midX, y: topDip),
            control1: CGPoint(x: rect.maxX + w * 0.05, y: rect.minY + h * 0.55),
            control2: CGPoint(x: rect.maxX + w * 0.10, y: rect.minY - h * 0.10)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Button style

struct HomeTilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

// Keep ScaleButtonStyle for other views that reference it
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

// MARK: - Profile Sheet (unchanged from current main)

struct ProfileSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showPairing = false
    @State private var showEmojiPicker = false
    @State private var coupleCodeCopied = false

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
                    coupleCodeRow
                    Spacer()
                    if viewModel.coupleID != nil { syncRow }
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
        .sheet(isPresented: $showEmojiPicker) { emojiPickerSheet }
    }

    private var emojiPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    Text(viewModel.currentProfile?.emoji ?? "😊").font(.system(size: 72))
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

    @ViewBuilder
    private var coupleCodeRow: some View {
        if let code = viewModel.coupleID {
            Button {
                UIPasteboard.general.string = code
                withAnimation { coupleCodeCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { coupleCodeCopied = false }
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.surfaceColor).frame(width: 48, height: 48)
                        Image(systemName: coupleCodeCopied ? "checkmark" : "person.2.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "C96E4B").opacity(0.85))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Pareringskod")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                            .textCase(.uppercase)
                            .tracking(0.8)
                        Text(coupleCodeCopied ? "Kopierat!" : code)
                            .font(.system(size: 17, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(16)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    private var syncRow: some View {
        Button { Task { await viewModel.syncFromCloud() } } label: {
            HStack(spacing: 10) {
                if viewModel.isSyncing {
                    ProgressView().tint(Color(hex: "C96E4B")).frame(width: 18, height: 18)
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
            Button { if isMe { showEmojiPicker = true } } label: {
                ZStack {
                    Circle().fill(Color.surfaceColor).frame(width: 56, height: 56)
                    Text(profile?.emoji ?? "?").font(.system(size: 30))
                    if isMe {
                        Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1.5)
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
