import SwiftUI

struct AddSubcategorySheet: View {
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name         = ""
    @State private var noteText     = ""
    @State private var selectedIcon: String
    @State private var isSaving     = false

    init(category: OursCategory) {
        self.category = category
        _selectedIcon = State(initialValue: category.suggestedIcons.first ?? "folder.fill")
    }

    private var accent: Color { Color(hex: category.colorHex1) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        field(label: "NAMN") {
                            TextField("", text: $name,
                                      prompt: Text(category.namePrompt).foregroundColor(.white.opacity(0.3)))
                                .font(.system(size: 17))
                                .foregroundColor(.white)
                                .padding(14)
                                .background(Color.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if let noteLabel = category.noteLabel {
                            field(label: noteLabel.uppercased()) {
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $noteText)
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 100)

                                    if noteText.isEmpty {
                                        Text(category.notePlaceholder)
                                            .font(.system(size: 15))
                                            .foregroundColor(.white.opacity(0.28))
                                            .padding(.top, 8)
                                            .padding(.leading, 5)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .padding(12)
                                .background(Color.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        field(label: "IKON") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                                      spacing: 8) {
                                ForEach(category.suggestedIcons, id: \.self) { icon in
                                    Button { selectedIcon = icon } label: {
                                        Image(systemName: icon)
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedIcon == icon ? accent : .white.opacity(0.4))
                                            .frame(width: 48, height: 48)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedIcon == icon
                                                        ? accent.opacity(0.15)
                                                        : Color.cardBackground)
                                            )
                                    }
                                }
                            }
                        }

                        Button {
                            guard !name.trimmingCharacters(in: .whitespaces).isEmpty, !isSaving else { return }
                            isSaving = true
                            Task {
                                await viewModel.addSubcategory(
                                    name: name.trimmingCharacters(in: .whitespaces),
                                    iconName: selectedIcon,
                                    note: noteText,
                                    to: category
                                )
                                dismiss()
                            }
                        } label: {
                            HStack {
                                if isSaving { ProgressView().tint(.white) }
                                else {
                                    Text("Lägg till")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: name.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? [Color.surfaceColor, Color.surfaceColor]
                                        : [Color(hex: category.colorHex1), Color(hex: category.colorHex2)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(category.addListTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.2)
            content()
        }
    }
}
