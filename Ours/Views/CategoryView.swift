import SwiftUI

struct CategoryView: View {
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showAddSheet = false
    @State private var editMode: EditMode = .inactive
    @State private var subToRename: OursSubcategory? = nil
    @State private var renameText = ""

    private var subcategories: [OursSubcategory] {
        viewModel.subcategoriesByCategory[category.id] ?? []
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !subcategories.isEmpty {
                        Button {
                            withAnimation { editMode = editMode == .active ? .inactive : .active }
                        } label: {
                            Image(systemName: editMode == .active ? "checkmark" : "arrow.up.arrow.down")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(editMode == .active ? 1 : 0.7))
                        }
                    }
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
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
                NavigationLink {
                    if category.useTripView {
                        TripDetailView(trip: sub, category: category)
                    } else {
                        SubcategoryView(subcategory: sub, category: category)
                    }
                } label: {
                    SubcategoryRow(subcategory: sub, category: category)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
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

            Button { showAddSheet = true } label: {
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: category.colorHex1).opacity(0.25),
                                     Color(hex: category.colorHex2).opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                Image(systemName: subcategory.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(hex: category.colorHex1))
            }

            Text(subcategory.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.25))
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
