import SwiftUI

struct SubcategoryView: View {
    let subcategory: OursSubcategory
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showAddBlock = false
    @State private var editMode: EditMode = .inactive
    @State private var noteText: String = ""
    @State private var itemToEdit: ListItem? = nil
    @State private var subToRename: OursSubcategory? = nil
    @State private var renameText = ""
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var quickAddText: String = ""
    @FocusState private var quickAddFocused: Bool
    @State private var sortByStore: Bool = false
    @State private var scrollProxy: ScrollViewProxy? = nil
    @Environment(\.openURL) private var openURL

    private var isShopping: Bool {
        category.id == UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    }

    private var items: [ListItem] {
        viewModel.itemsBySubcategory[subcategory.id] ?? []
    }

    private var children: [OursSubcategory] {
        viewModel.childSubcategories(of: subcategory)
    }

    private var blocks: [TripBlock] {
        viewModel.blocksByTrip[subcategory.id] ?? []
    }

    private var hasNoteSection: Bool { category.noteLabel != nil }
    private var isEmpty: Bool { items.isEmpty && children.isEmpty && blocks.isEmpty && !hasNoteSection }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea(.container)
            if !isEmpty { listContent } else { emptyState }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isSelecting { quickAddBar }
        }
        .onChange(of: quickAddFocused) { _, focused in
            guard focused else { return }
            // Keyboard is animating up (~0.25s) — scroll to bottom once it's in place
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollProxy?.scrollTo("listBottom", anchor: .bottom)
                }
            }
        }
        .navigationTitle(subcategory.name)
        .navigationBarTitleDisplayMode(.large)
        .fontDesign(.rounded)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !items.isEmpty || !children.isEmpty || !blocks.isEmpty {
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
                            if !items.isEmpty {
                                Button {
                                    withAnimation { isSelecting = true }
                                } label: {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                    if !isSelecting && isShopping && !items.isEmpty {
                        Button {
                            withAnimation { sortByStore.toggle() }
                        } label: {
                            Image(systemName: sortByStore ? "cart.fill" : "cart")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(sortByStore
                                                 ? Color(hex: category.colorHex1)
                                                 : .white.opacity(0.7))
                        }
                    }
                    if !isSelecting {
                        Button { showAddBlock = true } label: {
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
        .sheet(isPresented: $showAddBlock) {
            AddBlockSheet(trip: subcategory, category: category, blockTypes: [.note])
                .environmentObject(viewModel)
        }
        .sheet(item: $itemToEdit) { item in
            EditItemSheet(item: item, subcategory: subcategory, category: category)
                .environmentObject(viewModel)
        }
        .alert("Ändra namn", isPresented: Binding(
            get: { subToRename != nil },
            set: { if !$0 { subToRename = nil } }
        )) {
            TextField("Namn", text: $renameText)
            Button("Spara") {
                if let sub = subToRename, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    viewModel.renameSubcategory(sub,
                        to: renameText.trimmingCharacters(in: .whitespaces),
                        in: category)
                }
                subToRename = nil
            }
            Button("Avbryt", role: .cancel) { subToRename = nil }
        }
        .task {
            await viewModel.loadItems(for: subcategory)
            await viewModel.loadBlocks(for: subcategory)
            noteText = subcategory.note
        }
    }

    // MARK: - Unified row entry

    private enum RowEntry: Identifiable, Hashable {
        case category(OursSubcategory)
        case item(ListItem)
        case block(TripBlock)

        var id: String {
            switch self {
            case .category(let c): return "c-\(c.id.uuidString)"
            case .item(let i):     return "i-\(i.id.uuidString)"
            case .block(let b):    return "b-\(b.id.uuidString)"
            }
        }

        var order: Int {
            switch self {
            case .category(let c): return c.order
            case .item(let i):     return i.order
            case .block(let b):    return b.order
            }
        }
    }

    private var allRows: [RowEntry] {
        let cats = children.map { RowEntry.category($0) }
        let its = items.map { RowEntry.item($0) }
        let blks = blocks.map { RowEntry.block($0) }
        return (cats + its + blks).sorted { $0.order < $1.order }
    }

    private var nonItemRows: [RowEntry] {
        allRows.filter {
            switch $0 {
            case .category, .block: return true
            case .item:             return false
            }
        }
    }

    private var itemsBySection: [ShoppingSection: [ListItem]] {
        var result: [ShoppingSection: [ListItem]] = [:]
        for item in items {
            let section = GroceryCategorizer.section(for: item.title)
            result[section, default: []].append(item)
        }
        return result
    }

    private var sortedSections: [ShoppingSection] {
        itemsBySection.keys.sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - List

    private var listContent: some View {
        ScrollViewReader { proxy in
            List {
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

                if sortByStore && isShopping {
                    groupedByStoreSection
                } else if !allRows.isEmpty {
                    ForEach(allRows) { row in
                        rowView(for: row)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await deleteRow(row) }
                                } label: {
                                    Label("Ta bort", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                    }
                    .onMove { from, to in
                        handleMove(from: from, to: to)
                    }
                }

                // Invisible anchor — always at the bottom for auto-scroll after quick-add
                Color.clear
                    .frame(height: 1)
                    .id("listBottom")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .environment(\.editMode, $editMode)
            .onAppear { scrollProxy = proxy }
        }
    }

    @ViewBuilder
    private var groupedByStoreSection: some View {
        if !nonItemRows.isEmpty {
            ForEach(nonItemRows) { row in
                rowView(for: row)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await deleteRow(row) }
                        } label: {
                            Label("Ta bort", systemImage: "trash")
                        }
                        .tint(.red)
                    }
            }
        }
        ForEach(sortedSections) { section in
            Section {
                ForEach(itemsBySection[section] ?? []) { item in
                    itemRow(item)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteItem(item, from: subcategory) }
                            } label: {
                                Label("Ta bort", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
            } header: {
                sectionHeader(section.displayName.uppercased())
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    @ViewBuilder
    private func rowView(for row: RowEntry) -> some View {
        switch row {
        case .category(let child): childRow(child)
        case .item(let item):      itemRow(item)
        case .block(let block):    blockView(block)
        }
    }

    @ViewBuilder
    private func blockView(_ block: TripBlock) -> some View {
        switch block.type {
        case .note:         NoteBlockCard(block: block, category: category)
        case .checklist:    ChecklistBlockCard(block: block, category: category)
        case .photos:       PhotoBlockCard(block: block, category: category)
        case .list:         ListBlockCard(block: block, category: category)
        case .monthlyCosts: MonthlyCostsBlockCard(block: block, category: category)
        case .budget:       BudgetBlockCard(block: block, category: category)
        }
    }

    private func deleteRow(_ row: RowEntry) async {
        switch row {
        case .category(let child): await viewModel.deleteSubcategory(child, from: category)
        case .item(let item):      await viewModel.deleteItem(item, from: subcategory)
        case .block(let block):    await viewModel.deleteBlock(block)
        }
    }

    private func handleMove(from source: IndexSet, to destination: Int) {
        var arr = allRows
        arr.move(fromOffsets: source, toOffset: destination)
        for (idx, row) in arr.enumerated() {
            switch row {
            case .category(let sub):
                viewModel.updateSubcategoryOrder(sub.id, in: category, to: idx)
            case .item(let item):
                viewModel.updateItemOrder(item.id, in: subcategory, to: idx)
            case .block(let block):
                viewModel.updateBlockOrder(block.id, in: subcategory, to: idx)
            }
        }
    }

    private func itemURL(_ item: ListItem) -> URL? {
        if !item.url.isEmpty, let u = URL(string: item.url) { return u }
        return LinkDetector.extractURL(from: item.title)
    }

    @ViewBuilder
    private func itemRow(_ item: ListItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if isSelecting {
                Button { toggleSelection(item.id) } label: {
                    Image(systemName: selectedIDs.contains(item.id)
                          ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(selectedIDs.contains(item.id)
                                         ? Color(hex: category.colorHex1) : .white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            if category.isCheckable {
                Button {
                    if isSelecting { toggleSelection(item.id) }
                    else { Task { await viewModel.toggleItem(item, in: subcategory) } }
                } label: {
                    checkboxView(for: item)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            if let url = itemURL(item) {
                LinkPreviewBody(
                    url: url,
                    userTitle: item.title,
                    notes: item.notes,
                    accentHex: category.colorHex1,
                    onTap: {
                        if isSelecting { toggleSelection(item.id) }
                        else { openURL(url) }
                    }
                )
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Button {
                        if isSelecting { toggleSelection(item.id) }
                        else { itemToEdit = item }
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(category.isCheckable && item.isCompleted
                                                 ? .white.opacity(0.35) : .white)
                                .strikethrough(category.isCheckable && item.isCompleted,
                                               color: .white.opacity(0.3))
                                .multilineTextAlignment(.leading)
                            if !item.notes.isEmpty {
                                Text(item.notes)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor(.white.opacity(0.45))
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            if !isSelecting {
                Button { itemToEdit = item } label: {
                    Label("Ändra", systemImage: "pencil")
                }
                // Move down into a child subcategory
                let destinations = children
                if !destinations.isEmpty {
                    Menu {
                        ForEach(destinations) { child in
                            Button {
                                viewModel.moveItem(item, to: child)
                            } label: {
                                Label(child.name, systemImage: child.iconName)
                            }
                        }
                    } label: {
                        Label("Flytta till…", systemImage: "arrow.turn.down.right")
                    }
                }
                // Move up to parent subcategory
                if let parent = viewModel.parentSubcategory(of: subcategory) {
                    Button {
                        viewModel.moveItem(item, to: parent)
                    } label: {
                        Label("Flytta upp", systemImage: "arrow.turn.up.left")
                    }
                }
                Button(role: .destructive) {
                    Task { await viewModel.deleteItem(item, from: subcategory) }
                } label: {
                    Label("Ta bort", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func checkboxView(for item: ListItem) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    item.isCompleted ? Color(hex: category.colorHex1) : Color.white.opacity(0.25),
                    lineWidth: 2
                )
                .frame(width: 26, height: 26)
            if item.isCompleted {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: category.colorHex1), Color(hex: category.colorHex2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 20, height: 20)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .contentShape(Rectangle().inset(by: -8))
    }

    private func toggleSelection(_ id: UUID) {
        withAnimation {
            if selectedIDs.contains(id) { selectedIDs.remove(id) }
            else { selectedIDs.insert(id) }
        }
    }

    @ViewBuilder
    private func childRow(_ child: OursSubcategory) -> some View {
        NavigationLink {
            SubcategoryView(subcategory: child, category: category)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [Color(hex: category.colorHex1).opacity(0.22),
                                     Color(hex: category.colorHex2).opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Image(systemName: child.iconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: category.colorHex1))
                }
                Text(child.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                let count = childCount(of: child)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                renameText = child.name
                subToRename = child
            } label: {
                Label("Ändra namn", systemImage: "pencil")
            }
            Button(role: .destructive) {
                Task { await viewModel.deleteSubcategory(child, from: category) }
            } label: {
                Label("Ta bort kategori", systemImage: "trash")
            }
        }
    }

    private func childCount(of sub: OursSubcategory) -> Int {
        let kids = viewModel.childSubcategories(of: sub).count
        let its = (viewModel.itemsBySubcategory[sub.id] ?? []).count
        return kids + its
    }

    // MARK: - Note editor card

    private var noteEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $noteText)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .frame(height: 160)
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

    // MARK: - Quick-add bar (always visible at bottom)

    private var quickAddBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: category.colorHex1).opacity(0.65))
            TextField("",
                      text: $quickAddText,
                      prompt: Text("Lägg till sak…").foregroundColor(.white.opacity(0.3)))
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.white)
                .focused($quickAddFocused)
                .onSubmit { commitQuickAdd() }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.cardBackground)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.white.opacity(0.06)),
            alignment: .top
        )
    }

    private func commitQuickAdd() {
        let t = quickAddText.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        quickAddText = ""
        Task {
            if let url = LinkDetector.extractURL(from: t) {
                let urlStr = url.absoluteString
                await viewModel.addItem(title: urlStr, notes: "", url: urlStr, to: subcategory)
                LinkPreviewService.shared.fetchIfNeeded(urlStr)
            } else {
                await viewModel.addItem(title: t, notes: "", url: "", to: subcategory)
            }
            quickAddFocused = true
            // Brief pause for the list to render the new row, then scroll to it
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.easeOut(duration: 0.25)) {
                scrollProxy?.scrollTo("listBottom", anchor: .bottom)
            }
        }
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

// MARK: - Link preview row body

private struct LinkPreviewBody: View {
    let url: URL
    let userTitle: String
    let notes: String
    let accentHex: String
    let onTap: () -> Void

    @ObservedObject private var service = LinkPreviewService.shared

    private var meta: LinkPreviewService.Metadata? {
        service.metadata(for: url.absoluteString)
    }
    private var thumb: UIImage? {
        service.thumbnail(for: url.absoluteString)
    }

    private var displayTitle: String {
        let trimmed = userTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed != url.absoluteString { return trimmed }
        if let m = meta, !m.title.isEmpty, m.title != url.absoluteString { return m.title }
        return url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
    }

    private var sourceLabel: String {
        meta?.sourceName ?? LinkPreviewService.sourceLabel(for: url) ?? ""
    }

    private var sourceIcon: String {
        switch sourceLabel.lowercased() {
        case "youtube", "vimeo", "tiktok": return "play.fill"
        case "instagram": return "camera.fill"
        case "x":         return "bubble.left.fill"
        default:          return "link"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                thumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 5) {
                        Image(systemName: sourceIcon).font(.system(size: 10, weight: .semibold))
                        Text(sourceLabel.isEmpty ? (url.host ?? "") : sourceLabel)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundColor(Color(hex: accentHex))

                    if !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear { service.fetchIfNeeded(url.absoluteString) }
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            if let img = thumb {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(hex: accentHex).opacity(0.20),
                             Color(hex: accentHex).opacity(0.08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: sourceIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color(hex: accentHex).opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16.0/9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
