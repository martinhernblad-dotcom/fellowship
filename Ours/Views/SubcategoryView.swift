import SwiftUI

struct SubcategoryView: View {
    let subcategory: OursSubcategory
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showAddItem = false
    @State private var editMode: EditMode = .inactive
    @State private var noteText: String = ""
    @State private var itemToRename: ListItem? = nil
    @State private var renameText = ""
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []

    private var items: [ListItem] {
        viewModel.itemsBySubcategory[subcategory.id] ?? []
    }

    private var hasNoteSection: Bool { category.noteLabel != nil }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            Group {
                if hasNoteSection || !items.isEmpty {
                    listContent
                } else {
                    emptyState
                }
            }
        }
        .navigationTitle(subcategory.name)
        .navigationBarTitleDisplayMode(.large)
        .fontDesign(.rounded)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !items.isEmpty {
                        if isSelecting {
                            Button {
                                withAnimation {
                                    isSelecting = false
                                    selectedIDs = []
                                }
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
                        Button { showAddItem = true } label: {
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
                        let toDelete = items.filter { selectedIDs.contains($0.id) }
                        Task {
                            for item in toDelete {
                                await viewModel.deleteItem(item, from: subcategory)
                            }
                        }
                        withAnimation {
                            isSelecting = false
                            selectedIDs = []
                        }
                    } label: {
                        Label("Ta bort (\(selectedIDs.count))", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddItemSheet(subcategory: subcategory, category: category)
                .environmentObject(viewModel)
        }
        .task {
            await viewModel.loadItems(for: subcategory)
            noteText = subcategory.note
        }
        .alert("Ändra namn", isPresented: Binding(
            get: { itemToRename != nil },
            set: { if !$0 { itemToRename = nil } }
        )) {
            TextField("Namn", text: $renameText)
            Button("Spara") {
                if let item = itemToRename, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    viewModel.renameItem(item, to: renameText.trimmingCharacters(in: .whitespaces), in: subcategory)
                }
                itemToRename = nil
            }
            Button("Avbryt", role: .cancel) { itemToRename = nil }
        }
    }

    // MARK: - List

    private var listContent: some View {
        List {
            // Note section (Recept: instructions, Resor: trip info)
            if let noteLabel = category.noteLabel {
                Section {
                    noteEditor
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } header: {
                    sectionHeader(noteLabel)
                }
            }

            // Items section (ingredients / activities)
            Section {
                if items.isEmpty {
                    emptyItemsHint
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                } else {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            if isSelecting {
                                Image(systemName: selectedIDs.contains(item.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(selectedIDs.contains(item.id)
                                                     ? Color(hex: category.colorHex1) : .white.opacity(0.3))
                                    .onTapGesture {
                                        withAnimation {
                                            if selectedIDs.contains(item.id) {
                                                selectedIDs.remove(item.id)
                                            } else {
                                                selectedIDs.insert(item.id)
                                            }
                                        }
                                    }
                            }
                            ListItemRow(item: item, category: category) {
                                if isSelecting {
                                    withAnimation {
                                        if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) }
                                        else { selectedIDs.insert(item.id) }
                                    }
                                } else {
                                    Task { await viewModel.toggleItem(item, in: subcategory) }
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .contextMenu {
                            if !isSelecting {
                                Button {
                                    renameText = item.title
                                    itemToRename = item
                                } label: {
                                    Label("Ändra", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteItem(item, from: subcategory) }
                                } label: {
                                    Label("Ta bort", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .onMove { from, to in
                        viewModel.moveItem(in: subcategory, fromOffsets: from, toOffset: to)
                    }
                }
            } header: {
                if let label = category.itemsLabel {
                    sectionHeader(label)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
    }

    // MARK: - Note editor card

    private var noteEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $noteText)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110)
                .onChange(of: noteText) { _, newVal in
                    viewModel.updateNote(newVal, for: subcategory, in: category)
                }

            if noteText.isEmpty {
                Text(category.notePlaceholder)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.white.opacity(0.28))
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Empty items hint (shown inside list when items are empty but note section exists)

    private var emptyItemsHint: some View {
        Button { showAddItem = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: category.colorHex1).opacity(0.7))
                Text(category.itemsLabel == "Ingredienser" ? "Lägg till ingrediens" : "Lägg till aktivitet")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.4))
            .tracking(1.0)
            .padding(.leading, 4)
            .padding(.bottom, 2)
    }

    // MARK: - Empty state (no note section, no items)

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: subcategory.iconName)
                .font(.system(size: 48))
                .foregroundColor(Color(hex: category.colorHex1).opacity(0.45))
            Text("Inget här ännu")
                .font(.title3.bold())
                .foregroundColor(.white.opacity(0.75))
            Text("Tryck + för att lägga till")
                .font(.body)
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - List Item Row

struct ListItemRow: View {
    let item: ListItem
    let category: OursCategory
    let onToggle: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if category.isCheckable {
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                item.isCompleted
                                    ? Color(hex: category.colorHex1)
                                    : Color.white.opacity(0.25),
                                lineWidth: 2
                            )
                            .frame(width: 26, height: 26)

                        if item.isCompleted {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: category.colorHex1), Color(hex: category.colorHex2)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 20, height: 20)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(category.isCheckable && item.isCompleted ? .white.opacity(0.35) : .white)
                    .strikethrough(category.isCheckable && item.isCompleted, color: .white.opacity(0.3))

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(3)
                }

                if !item.url.isEmpty, let url = URL(string: item.url) {
                    Button { openURL(url) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 11))
                            Text(url.host ?? item.url)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                        .foregroundColor(Color(hex: category.colorHex1))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: item.isCompleted)
    }
}
