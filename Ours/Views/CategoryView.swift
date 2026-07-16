import SwiftUI

struct CategoryView: View {
    let category: OursCategory
    var parent: OursSubcategory? = nil   // non-nil when browsing inside a recipe group
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showAddSheet = false
    @State private var showAddCategorySheet = false
    @State private var showRecipeChoice = false
    @State private var editMode: EditMode = .inactive
    @State private var subToRename: OursSubcategory? = nil
    @State private var renameText = ""
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []

    private var subcategories: [OursSubcategory] {
        (viewModel.subcategoriesByCategory[category.id] ?? [])
            .filter { $0.parentSubcategoryID == parent?.id }
    }

    private func recipeCount(in group: OursSubcategory) -> Int {
        (viewModel.subcategoriesByCategory[category.id] ?? [])
            .filter { $0.parentSubcategoryID == group.id }.count
    }

    // What the plus button does depends on where we are:
    // - Recept top level: choose between new recipe and new category (group)
    // - inside a recipe group: recipes only
    // - everywhere else: the normal new-list sheet
    private func addTapped() {
        if category.usesRecipeImport {
            if parent == nil { showRecipeChoice = true }
            else             { showAddSheet = true }
        } else {
            showAddCategorySheet = true
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea(.container)

            Group {
                if subcategories.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
        }
        .navigationTitle(parent?.name ?? category.name)
        .navigationBarTitleDisplayMode(.large)
        .fontDesign(.rounded)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !subcategories.isEmpty {
                        if isSelecting {
                            Button {
                                withAnimation { isSelecting = false; selectedIDs = [] }
                            } label: {
                                Text("Avbryt")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        } else {
                            Button {
                                withAnimation { editMode = editMode == .active ? .inactive : .active }
                            } label: {
                                Image(systemName: editMode == .active ? "checkmark" : "arrow.up.arrow.down")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white.opacity(editMode == .active ? 1 : 0.7))
                            }
                            Button {
                                withAnimation { isSelecting = true }
                            } label: {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    if !isSelecting {
                        Button {
                            addTapped()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            if isSelecting && !selectedIDs.isEmpty {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .destructive) {
                        let toDelete = subcategories.filter { selectedIDs.contains($0.id) }
                        Task {
                            await viewModel.deleteSubcategories(toDelete, from: category)
                        }
                        withAnimation { isSelecting = false; selectedIDs = [] }
                    } label: {
                        Label("Ta bort (\(selectedIDs.count))", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .confirmationDialog("Lägg till", isPresented: $showRecipeChoice) {
            Button("Nytt recept")  { showAddSheet = true }
            Button("Ny kategori")  { showAddCategorySheet = true }
        }
        .sheet(isPresented: $showAddSheet) {
            RecipeImportSheet(category: category, parent: parent)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showAddCategorySheet) {
            AddSubcategorySheet(category: category, parent: parent,
                                asGroup: category.usesRecipeImport)
                .environmentObject(viewModel)
        }
        .task { await viewModel.loadSubcategories(for: category) }
        .alert("Ändra namn", isPresented: Binding(
            get: { subToRename != nil },
            set: { if !$0 { subToRename = nil } }
        )) {
            TextField("Namn", text: $renameText)
            Button("Spara") {
                if let sub = subToRename, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    viewModel.renameSubcategory(sub, to: renameText.trimmingCharacters(in: .whitespaces), in: category)
                }
                subToRename = nil
            }
            Button("Avbryt", role: .cancel) { subToRename = nil }
        }
    }

    // MARK: - List

    private var listContent: some View {
        List {
            ForEach(subcategories) { sub in
                HStack(spacing: 12) {
                    if isSelecting {
                        Image(systemName: selectedIDs.contains(sub.id)
                              ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(selectedIDs.contains(sub.id)
                                             ? Color(hex: category.colorHex1) : .white.opacity(0.3))
                            .onTapGesture {
                                withAnimation {
                                    if selectedIDs.contains(sub.id) { selectedIDs.remove(sub.id) }
                                    else { selectedIDs.insert(sub.id) }
                                }
                            }
                    }
                    if isSelecting {
                        SubcategoryRow(subcategory: sub, category: category)
                            .onTapGesture {
                                withAnimation {
                                    if selectedIDs.contains(sub.id) { selectedIDs.remove(sub.id) }
                                    else { selectedIDs.insert(sub.id) }
                                }
                            }
                    } else {
                        NavigationLink {
                            if sub.isGroup {
                                CategoryView(category: category, parent: sub)
                            } else if category.useTripView {
                                TripDetailView(trip: sub, category: category)
                            } else {
                                SubcategoryView(subcategory: sub, category: category)
                            }
                        } label: {
                            SubcategoryRow(subcategory: sub, category: category,
                                           groupCount: sub.isGroup ? recipeCount(in: sub) : nil)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                renameText = sub.name
                                subToRename = sub
                            } label: {
                                Label("Ändra", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                Task { await viewModel.deleteSubcategory(sub, from: category) }
                            } label: {
                                Label("Ta bort lista", systemImage: "trash")
                            }
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            }
            .onMove { from, to in
                viewModel.moveSubcategory(in: category, parentID: parent?.id,
                                          fromOffsets: from, toOffset: to)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: category.iconName)
                .font(.system(size: 52))
                .foregroundColor(Color(hex: category.colorHex1).opacity(0.5))

            Text(category.usesRecipeImport ? "Inga recept än" : "Inga listor än")
                .font(.title3.bold())
                .foregroundColor(.white.opacity(0.8))

            Text(category.usesRecipeImport
                 ? "Tryck + för att lägga till ett recept"
                 : "Tryck + för att skapa din första lista")
                .font(.body)
                .foregroundColor(.white.opacity(0.35))

            Button {
                addTapped()
            } label: {
                Label(category.usesRecipeImport ? "Lägg till recept" : "Lägg till lista",
                      systemImage: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: category.colorHex1), Color(hex: category.colorHex2)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Subcategory Row

struct SubcategoryRow: View {
    let subcategory: OursSubcategory
    let category: OursCategory
    var groupCount: Int? = nil   // shown for recipe groups: count + chevron

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: category.colorHex1).opacity(0.25),
                                     Color(hex: category.colorHex2).opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                Image(systemName: subcategory.iconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: category.colorHex1))
            }

            Text(subcategory.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            if let groupCount {
                Text("\(groupCount)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.25))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
