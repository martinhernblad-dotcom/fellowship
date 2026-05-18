import SwiftUI

struct AddBlockSheet: View {
    let trip: OursSubcategory
    let category: OursCategory
    let blockTypes: [TripBlockType]
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title        = ""
    @State private var selected:    EntryKind
    @State private var subTripIcon: String
    @State private var isSaving     = false

    init(trip: OursSubcategory, category: OursCategory, blockTypes: [TripBlockType]? = nil) {
        self.trip = trip; self.category = category
        let types = blockTypes ?? category.availableBlockTypes
        self.blockTypes = types
        let initial: EntryKind
        if let first = types.first {
            initial = .block(first)
        } else if category.allowsNestedSubcategories {
            initial = .subTrip
        } else {
            initial = .block(.note)
        }
        _selected = State(initialValue: initial)
        _subTripIcon = State(initialValue: category.suggestedIcons.first ?? "folder.fill")
    }

    private enum EntryKind: Hashable {
        case block(TripBlockType)
        case subTrip
    }

    private var entries: [(EntryKind, String, String)] {
        var out: [(EntryKind, String, String)] = blockTypes.map { type in
            switch type {
            case .checklist:    return (.block(type), "checkmark.square.fill", "Checklista")
            case .note:         return (.block(type), "text.alignleft",        "Anteckning")
            case .photos:       return (.block(type), "photo.fill",            "Foton")
            case .list:         return (.block(type), "list.bullet",           "Lista")
            case .monthlyCosts: return (.block(type), "chart.bar.fill",        "Kostnader")
            case .budget:       return (.block(type), "chart.pie.fill",        "Budget")
            }
        }
        if category.allowsNestedSubcategories {
            out.append((.subTrip, "folder.fill", "Kategori"))
        }
        return out
    }

    private var isSubTrip: Bool {
        if case .subTrip = selected { return true }
        return false
    }

    private var effectiveTitle: String {
        let t = title.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { return t }
        switch selected {
        case .block(.photos):       return "Foton"
        case .block(.monthlyCosts): return "Månadskostnader"
        case .block(.budget):       return "Budget"
        default:                    return ""
        }
    }

    private var accent: Color { Color(hex: category.colorHex1) }

    private var placeholder: String {
        switch selected {
        case .block(.checklist):    return "T.ex. Packlista, Aktiviteter…"
        case .block(.note):         return "T.ex. Anteckningar, Information…"
        case .block(.photos):       return "T.ex. Foton, Inspiration…"
        case .block(.list):         return "T.ex. Prenumerationer, Mål…"
        case .block(.monthlyCosts): return "T.ex. Januari 2025…"
        case .block(.budget):       return "T.ex. Martins budget, Gemensam…"
        case .subTrip:
            return "T.ex. Storhandling, Tokyo, Måste-ha…"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea(.container)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            label("TYP")
                            let cols = entries.count <= 3 ? entries.count : (entries.count == 4 ? 2 : 3)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: cols),
                                      spacing: 12) {
                                ForEach(entries, id: \.0) { (kind, icon, name) in
                                    typeButton(kind, icon: icon, name: name)
                                }
                            }
                        }

                        if !isPhotosBlock {
                            VStack(alignment: .leading, spacing: 10) {
                                label("NAMN")
                                TextField("", text: $title,
                                          prompt: Text(placeholder).foregroundColor(.white.opacity(0.3)))
                                    .font(.system(size: 17, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(14)
                                    .background(Color.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        if isSubTrip {
                            VStack(alignment: .leading, spacing: 10) {
                                label("IKON")
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                                          spacing: 8) {
                                    ForEach(category.suggestedIcons, id: \.self) { icon in
                                        Button { subTripIcon = icon } label: {
                                            Image(systemName: icon)
                                                .font(.system(size: 18))
                                                .foregroundColor(subTripIcon == icon ? accent : .white.opacity(0.4))
                                                .frame(width: 44, height: 44)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(subTripIcon == icon
                                                            ? accent.opacity(0.15)
                                                            : Color.cardBackground)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Button { save() } label: {
                            HStack {
                                if isSaving { ProgressView().tint(.white) }
                                else {
                                    Text("Skapa")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient(
                                colors: effectiveTitle.isEmpty
                                    ? [Color.surfaceColor, Color.surfaceColor]
                                    : [Color(hex: category.colorHex1), Color(hex: category.colorHex2)],
                                startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(effectiveTitle.isEmpty || isSaving)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Lägg till")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") { dismiss() }.foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var isPhotosBlock: Bool {
        if case .block(.photos) = selected { return true }
        return false
    }

    private func save() {
        guard !effectiveTitle.isEmpty, !isSaving else { return }
        isSaving = true
        Task {
            switch selected {
            case .block(let type):
                await viewModel.addBlock(title: effectiveTitle, type: type, to: trip)
            case .subTrip:
                await viewModel.addSubcategory(
                    name: effectiveTitle,
                    iconName: subTripIcon,
                    parentSubcategoryID: trip.id,
                    to: category
                )
            }
            dismiss()
        }
    }

    private func typeButton(_ kind: EntryKind, icon: String, name: String) -> some View {
        Button { selected = kind } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(selected == kind ? accent : .white.opacity(0.35))
                Text(name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(selected == kind ? .white : .white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected == kind ? accent.opacity(0.12) : Color.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(selected == kind ? accent.opacity(0.45) : Color.clear,
                                      lineWidth: 1.5))
            )
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.4))
            .tracking(1.2)
    }
}
