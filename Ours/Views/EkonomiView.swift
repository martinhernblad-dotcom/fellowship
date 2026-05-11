import SwiftUI

struct EkonomiView: View {
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel

    private var sections: [OursSubcategory] {
        (viewModel.subcategoriesByCategory[category.id] ?? [])
            .filter { $0.parentSubcategoryID == nil }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if sections.isEmpty {
                ProgressView().tint(.white)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                            NavigationLink {
                                TripDetailView(trip: section, category: category)
                                    .environmentObject(viewModel)
                            } label: {
                                EkonomiSectionCard(section: section, category: category, index: index)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.createEkonomiSectionsIfNeeded() }
    }
}

struct EkonomiSectionCard: View {
    let section: OursSubcategory
    let category: OursCategory
    let index: Int

    private var accent: Color { Color(hex: category.colorHex1) }

    private var cardColors: [Color] {
        switch index {
        case 0: return [Color(hex: category.colorHex1), Color(hex: category.colorHex2)]
        case 1: return [Color(hex: category.colorHex2), Color(hex: category.colorHex1)]
        default: return [Color(hex: "5A5240"), Color(hex: "3A3228")]
        }
    }

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: section.iconName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(section.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Tryck för att öppna")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(20)
        .background(
            LinearGradient(colors: cardColors, startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
    }
}
