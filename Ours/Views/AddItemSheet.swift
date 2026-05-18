import SwiftUI

struct AddItemSheet: View {
    let subcategory: OursSubcategory
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title     = ""
    @State private var notes     = ""
    @State private var url       = ""
    @State private var showNotes = false
    @State private var showURL   = false
    @State private var isSaving  = false

    @FocusState private var titleFocused: Bool

    private var accent: Color { Color(hex: category.colorHex1) }
    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea(.container)
                scrollContent
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .animation(.spring(response: 0.3), value: showNotes)
            .animation(.spring(response: 0.3), value: showURL)
            .onAppear { titleFocused = true }
        }
        .preferredColorScheme(.dark)
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                titleField
                optionalToggles
                if showNotes { notesField.transition(.move(edge: .top).combined(with: .opacity)) }
                if showURL   { urlField.transition(.move(edge: .top).combined(with: .opacity)) }
                Spacer(minLength: 40)
                saveButton
            }
            .padding(20)
        }
    }

    private var titleField: some View {
        TextField("", text: $title,
                  prompt: Text("What's the item?").foregroundColor(.white.opacity(0.3)))
            .font(.system(size: 18))
            .foregroundColor(.white)
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .focused($titleFocused)
    }

    private var optionalToggles: some View {
        HStack(spacing: 10) {
            toggleChip(icon: "text.justify.left", label: "Notes", isOn: $showNotes)
            toggleChip(icon: "link",              label: "Link",  isOn: $showURL)
            Spacer()
        }
    }

    private var notesField: some View {
        TextField("", text: $notes,
                  prompt: Text("Add notes…").foregroundColor(.white.opacity(0.3)),
                  axis: .vertical)
            .font(.system(size: 15))
            .foregroundColor(.white)
            .lineLimit(3...8)
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var urlField: some View {
        TextField("", text: $url,
                  prompt: Text("https://…").foregroundColor(.white.opacity(0.3)))
            .font(.system(size: 15))
            .foregroundColor(.white)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(14)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var saveButton: some View {
        Button {
            guard isValid, !isSaving else { return }
            isSaving = true
            Task {
                await viewModel.addItem(
                    title: title.trimmingCharacters(in: .whitespaces),
                    notes: notes, url: url, to: subcategory)
                dismiss()
            }
        } label: {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Add Item")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isValid
                        ? [Color(hex: category.colorHex1), Color(hex: category.colorHex2)]
                        : [Color.surfaceColor, Color.surfaceColor],
                    startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isValid || isSaving)
    }

    private func toggleChip(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        Button { isOn.wrappedValue.toggle() } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isOn.wrappedValue ? accent : .white.opacity(0.45))
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isOn.wrappedValue ? accent.opacity(0.15) : Color.cardBackground)
            )
        }
    }
}

// MARK: - Edit Item Sheet

struct EditItemSheet: View {
    let item: ListItem
    let subcategory: OursSubcategory
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var notes: String
    @State private var url: String

    init(item: ListItem, subcategory: OursSubcategory, category: OursCategory) {
        self.item = item; self.subcategory = subcategory; self.category = category
        _title = State(initialValue: item.title)
        _notes = State(initialValue: item.notes)
        _url   = State(initialValue: item.url)
    }

    private var accent: Color { Color(hex: category.colorHex1) }
    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea(.container)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        fieldLabel("NAMN")
                        TextField("", text: $title,
                                  prompt: Text("Namn").foregroundColor(.white.opacity(0.3)))
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        fieldLabel("ANTECKNINGAR")
                        TextField("", text: $notes,
                                  prompt: Text("Lägg till anteckningar…").foregroundColor(.white.opacity(0.3)),
                                  axis: .vertical)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .lineLimit(3...8)
                            .padding(14)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        fieldLabel("LÄNK")
                        TextField("", text: $url,
                                  prompt: Text("https://…").foregroundColor(.white.opacity(0.3)))
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(14)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Spacer(minLength: 40)

                        Button {
                            guard isValid else { return }
                            viewModel.updateItem(item,
                                title: title.trimmingCharacters(in: .whitespaces),
                                notes: notes, url: url, in: subcategory)
                            dismiss()
                        } label: {
                            Text("Spara")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(LinearGradient(
                                    colors: isValid
                                        ? [Color(hex: category.colorHex1), Color(hex: category.colorHex2)]
                                        : [Color.surfaceColor, Color.surfaceColor],
                                    startPoint: .leading, endPoint: .trailing))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!isValid)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Ändra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") { dismiss() }.foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.4))
            .tracking(1.2)
    }
}
