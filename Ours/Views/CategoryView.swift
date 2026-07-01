import SwiftUI

struct CategoryView: View {
    let category: OursCategory
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
            .filter { $0.parentSubcategoryID == nil }
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
        .navigationTitle(category.name)
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
                            if category.usesRecipeImport {
                                showRecipeChoice = true
                            } else {
                                showAddSheet = true
                            }
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
                            for sub in toDelete {
                                await viewModel.deleteSubcategory(sub, from: category)
                            }
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
            Button("Importera recept") { showAddSheet = true }
            Button("Ny kategori")     { showAddCategorySheet = true }
        }
        .sheet(isPresented: $showAddSheet) {
            RecipeImportSheet(category: category)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showAddCategorySheet) {
            AddSubcategorySheet(category: category)
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
                            if category.useTripView {
                                TripDetailView(trip: sub, category: category)
                            } else {
                                SubcategoryView(subcategory: sub, category: category)
                            }
                        } label: {
                            SubcategoryRow(subcategory: sub, category: category)
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
                viewModel.moveSubcategory(in: category, fromOffsets: from, toOffset: to)
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

            Text("Inga listor än")
                .font(.title3.bold())
                .foregroundColor(.white.opacity(0.8))

            Text("Tryck + för att skapa din första lista")
                .font(.body)
                .foregroundColor(.white.opacity(0.35))

            Button {
                if category.usesRecipeImport { showRecipeChoice = true } else { showAddSheet = true }
            } label: {
                Label("Lägg till lista", systemImage: "plus")
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
