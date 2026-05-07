import SwiftUI

struct AddBlockSheet: View {
    let trip: OursSubcategory
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title        = ""
    @State private var selectedType = TripBlockType.checklist
    @State private var isSaving     = false

    private var effectiveTitle: String {
        selectedType == .photos && title.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Foton" : title.trimmingCharacters(in: .whitespaces)
    }

    private var accent: Color { Color(hex: category.colorHex1) }

    private var placeholder: String {
        switch selectedType {
        case .checklist: return "T.ex. Packlista, Aktiviteter, Ingredienser…"
        case .note:      return "T.ex. Flyginformation, Instruktioner, Anteckningar…"
        case .photos:    return "T.ex. Foton, Inspiration…"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 28) {
                    // Type picker
                    VStack(alignment: .leading, spacing: 10) {
                        label("TYP")
                        HStack(spacing: 12) {
                            typeButton(.checklist, icon: "checkmark.square.fill", name: "Checklista")
                            typeButton(.note,      icon: "text.alignleft",        name: "Anteckning")
                            typeButton(.photos,    icon: "photo.fill",            name: "Foton")
                        }
                    }

                    // Name
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

                    Spacer()

                    // Create button
                    Button {
                        let t = title.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty, !isSaving else { return }
                        isSaving = true
                        Task {
                            await viewModel.addBlock(title: t, type: selectedType, to: trip)
                            dismiss()
                        }
                    } label: {
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
            .navigationTitle("Ny sektion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") { dismiss() }.foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func typeButton(_ type: TripBlockType, icon: String, name: String) -> some View {
        Button { selectedType = type } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(selectedType == type ? accent : .white.opacity(0.35))
                Text(name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(selectedType == type ? .white : .white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selectedType == type ? accent.opacity(0.12) : Color.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(selectedType == type ? accent.opacity(0.45) : Color.clear,
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
