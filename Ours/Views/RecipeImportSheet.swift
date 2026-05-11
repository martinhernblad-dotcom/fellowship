import SwiftUI
import UIKit

struct RecipeImportSheet: View {
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .chooseSource
    @State private var draft: RecipeDraft = .empty
    @State private var selectedIcon: String
    @State private var urlText: String = ""
    @State private var errorMessage: String? = nil
    @State private var isSaving = false
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false

    init(category: OursCategory) {
        self.category = category
        _selectedIcon = State(initialValue: category.suggestedIcons.first ?? "fork.knife")
    }

    private enum Step: Equatable {
        case chooseSource
        case enterURL
        case parsing(String)
        case preview
    }

    private var accent: Color { Color(hex: category.colorHex1) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                content
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(leftButtonTitle) { onLeftButton() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .confirmationDialog("Foto av recept",
                                isPresented: $photoSourceChoice,
                                titleVisibility: .visible) {
                Button("Ta foto") {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showCameraPicker = true
                    } else {
                        errorMessage = "Kameran är inte tillgänglig på den här enheten."
                    }
                }
                Button("Välj från bibliotek") { showLibraryPicker = true }
                Button("Avbryt", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showCameraPicker) {
            ImagePicker(sourceType: .camera,
                        onPicked: { handlePickedImage($0) },
                        onCancel: {})
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showLibraryPicker) {
            ImagePicker(sourceType: .photoLibrary,
                        onPicked: { handlePickedImage($0) },
                        onCancel: {})
                .ignoresSafeArea()
        }
    }

    // MARK: - Routing

    private var navTitle: String {
        switch step {
        case .chooseSource:        return "Nytt recept"
        case .enterURL:            return "Klistra in länk"
        case .parsing:             return "Hämtar…"
        case .preview:             return "Granska"
        }
    }

    private var leftButtonTitle: String {
        step == .chooseSource ? "Avbryt" : "Tillbaka"
    }

    private func onLeftButton() {
        switch step {
        case .chooseSource:
            dismiss()
        case .enterURL, .parsing, .preview:
            step = .chooseSource
            errorMessage = nil
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .chooseSource: chooseSourceView
        case .enterURL:     enterURLView
        case .parsing(let label): parsingView(label: label)
        case .preview:      previewView
        }
    }

    // MARK: - Step 1: choose source

    private var chooseSourceView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                sourceCard(
                    icon: "link",
                    title: "Klistra in länk",
                    subtitle: "Hämtar ett recept från en hemsida automatiskt"
                ) { step = .enterURL }

                sourceCard(
                    icon: "camera.fill",
                    title: "Ta foto av kokbok",
                    subtitle: "Läser av sidan och fyller i recept åt dig"
                ) { startPhotoImport() }

                sourceCard(
                    icon: "square.and.pencil",
                    title: "Tomt recept",
                    subtitle: "Börja från grunden och fyll i själv"
                ) {
                    draft = .empty
                    step = .preview
                }
            }
            .padding(20)
        }
    }

    private func sourceCard(icon: String, title: String, subtitle: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(
                            colors: [accent.opacity(0.25), Color(hex: category.colorHex2).opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(16)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Step 2a: URL entry

    private var enterURLView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("LÄNK")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1.2)
                TextField("",
                          text: $urlText,
                          prompt: Text("https://…").foregroundColor(.white.opacity(0.3)))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(14)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let error = errorMessage {
                    errorBanner(error)
                }

                primaryButton(title: "Hämta recept",
                              enabled: !urlText.trimmingCharacters(in: .whitespaces).isEmpty) {
                    importFromURL()
                }
                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private func importFromURL() {
        let input = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        errorMessage = nil
        step = .parsing("Hämtar recept…")
        Task {
            do {
                let result = try await RecipeURLImporter.importFrom(urlString: input)
                draft = result
                if !draft.name.isEmpty { /* keep current icon */ }
                step = .preview
            } catch {
                errorMessage = errorText(for: error)
                step = .enterURL
            }
        }
    }

    // MARK: - Step 2b: photo flow

    @State private var photoSourceChoice = false

    private func startPhotoImport() {
        photoSourceChoice = true
    }

    private func handlePickedImage(_ data: Data) {
        errorMessage = nil
        step = .parsing("Läser av bilden…")
        Task {
            do {
                let result = try await RecipePhotoImporter.importFrom(imageData: data)
                draft = result
                step = .preview
            } catch {
                errorMessage = errorText(for: error)
                step = .chooseSource
            }
        }
    }

    // MARK: - Parsing state

    private func parsingView(label: String) -> some View {
        VStack(spacing: 16) {
            ProgressView().tint(accent).scaleEffect(1.2)
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Step 3: preview / edit

    private var previewView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                if draft.sourceURL != nil || !draft.name.isEmpty || !draft.ingredients.isEmpty {
                    sourceBadge
                }

                field(label: "NAMN") {
                    TextField("",
                              text: $draft.name,
                              prompt: Text(category.namePrompt).foregroundColor(.white.opacity(0.3)))
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .padding(14)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                field(label: "INGREDIENSER") {
                    IngredientsEditor(ingredients: $draft.ingredients, accent: accent)
                }

                field(label: "INSTRUKTIONER") {
                    instructionsEditor
                }

                field(label: "IKON") {
                    iconGrid
                }

                if let error = errorMessage { errorBanner(error) }

                primaryButton(title: "Skapa recept",
                              enabled: !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
                                       && !isSaving,
                              loading: isSaving) {
                    saveRecipe()
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    private var sourceBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: draft.sourceURL == nil ? "sparkles" : "link")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(accent)
            Text(badgeText)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(accent.opacity(0.12))
        .clipShape(Capsule())
    }

    private var badgeText: String {
        if let url = draft.sourceURL,
           let host = URL(string: url)?.host {
            return "Hämtad från \(host)"
        }
        if !draft.ingredients.isEmpty || !draft.instructions.isEmpty {
            return "Avläst från foto"
        }
        return "Tomt recept"
    }

    private var instructionsEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $draft.instructions)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 140)
            if draft.instructions.isEmpty {
                Text(category.notePlaceholder)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.28))
                    .padding(.top, 8).padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var iconGrid: some View {
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
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Save

    private func saveRecipe() {
        guard !isSaving else { return }
        let trimmedName = draft.name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        isSaving = true
        var finalDraft = draft
        finalDraft.name = trimmedName
        finalDraft.iconHint = selectedIcon
        Task {
            await viewModel.createRecipeFromDraft(finalDraft, in: category)
            dismiss()
        }
    }

    // MARK: - UI helpers

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

    private func primaryButton(title: String, enabled: Bool,
                               loading: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if loading { ProgressView().tint(.white) }
                else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: enabled
                        ? [Color(hex: category.colorHex1), Color(hex: category.colorHex2)]
                        : [Color.surfaceColor, Color.surfaceColor],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!enabled)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(red: 0.9, green: 0.45, blue: 0.4))
            Text(message)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(red: 0.6, green: 0.25, blue: 0.22).opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func errorText(for error: Error) -> String {
        if let e = error as? RecipeImportError {
            switch e {
            case .invalidURL:    return "Ogiltig länk."
            case .fetchFailed:   return "Kunde inte hämta sidan."
            case .nothingUseful: return "Hittade inget recept att läsa in."
            }
        }
        return "Något gick fel. Försök igen."
    }
}

// MARK: - Ingredients editor

private struct IngredientsEditor: View {
    @Binding var ingredients: [String]
    let accent: Color
    @State private var newItem: String = ""
    @FocusState private var addFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !ingredients.isEmpty {
                VStack(spacing: 0) {
                    ForEach(ingredients.indices, id: \.self) { idx in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(accent.opacity(0.5))
                                .frame(width: 5, height: 5)
                            TextField("",
                                      text: Binding(
                                        get: { ingredients[idx] },
                                        set: { ingredients[idx] = $0 }
                                      ),
                                      prompt: Text("Ingrediens").foregroundColor(.white.opacity(0.3)))
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                            Button {
                                ingredients.remove(at: idx)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.25))
                                    .padding(8)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        if idx < ingredients.count - 1 {
                            Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 14)
                        }
                    }
                }
                Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 14)
            }

            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundColor(accent.opacity(0.55))
                TextField("",
                          text: $newItem,
                          prompt: Text("Lägg till ingrediens…").foregroundColor(.white.opacity(0.22)))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white)
                    .focused($addFocused)
                    .onSubmit { commit() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func commit() {
        let t = newItem.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        ingredients.append(t)
        newItem = ""
        addFocused = true
    }
}
