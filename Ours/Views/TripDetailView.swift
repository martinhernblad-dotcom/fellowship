import SwiftUI

// MARK: - Trip Detail (block-based layout for Resor)

struct TripDetailView: View {
    let trip: OursSubcategory
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showAddBlock = false
    @State private var editMode: EditMode = .inactive

    private var blocks: [TripBlock] {
        viewModel.blocksByTrip[trip.id] ?? []
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if blocks.isEmpty { emptyState } else { blockList }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !blocks.isEmpty {
                        Button {
                            withAnimation { editMode = editMode == .active ? .inactive : .active }
                        } label: {
                            Image(systemName: editMode == .active ? "checkmark" : "arrow.up.arrow.down")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(editMode == .active ? .white : .white.opacity(0.7))
                        }
                    }
                    Button { showAddBlock = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddBlock) {
            AddBlockSheet(trip: trip, category: category).environmentObject(viewModel)
        }
        .task { await viewModel.loadBlocks(for: trip) }
    }

    // MARK: - Block list

    private var blockList: some View {
        List {
            ForEach(blocks) { block in
                Group {
                    switch block.type {
                    case .note:       NoteBlockCard(block: block, category: category)
                    case .checklist:  ChecklistBlockCard(block: block, category: category)
                    }
                }
                .environmentObject(viewModel)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onMove { viewModel.moveBlock(tripID: trip.id, fromOffsets: $0, toOffset: $1) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "plus.square.dashed")
                .font(.system(size: 52))
                .foregroundColor(Color(hex: category.colorHex1).opacity(0.4))
            Text("Starta din resa")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            Text("Lägg till checklistor och anteckningar\nsom flyginformation, boende och mer.")
                .font(.body)
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)
            Button { showAddBlock = true } label: {
                Label("Lägg till sektion", systemImage: "plus")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(LinearGradient(
                        colors: [Color(hex: category.colorHex1), Color(hex: category.colorHex2)],
                        startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Note Block Card

struct NoteBlockCard: View {
    let block: TripBlock
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var title: String
    @State private var text: String

    init(block: TripBlock, category: OursCategory) {
        self.block = block; self.category = category
        _title = State(initialValue: block.title)
        _text  = State(initialValue: block.text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: category.colorHex1).opacity(0.8))
                TextField("", text: $title,
                          prompt: Text("Rubrik").foregroundColor(.white.opacity(0.3)))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .onChange(of: title) { viewModel.updateBlockTitle($0, for: block) }
                Spacer()
                blockMenu
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 10)

            Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 14)

            // Text body
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72)
                    .onChange(of: text) { viewModel.updateBlockText($0, for: block) }
                if text.isEmpty {
                    Text("Skriv anteckning…")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.22))
                        .padding(.top, 8).padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var blockMenu: some View {
        Menu {
            Button(role: .destructive) {
                Task { await viewModel.deleteBlock(block) }
            } label: { Label("Ta bort sektion", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.28))
                .padding(8)
        }
    }
}

// MARK: - Checklist Block Card

struct ChecklistBlockCard: View {
    let block: TripBlock
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var title: String
    @State private var newItemText = ""
    @FocusState private var addFieldFocused: Bool

    init(block: TripBlock, category: OursCategory) {
        self.block = block; self.category = category
        _title = State(initialValue: block.title)
    }

    private var items: [TripCheckItem] {
        viewModel.checkItemsByBlock[block.id] ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: category.colorHex1).opacity(0.8))
                TextField("", text: $title,
                          prompt: Text("Rubrik").foregroundColor(.white.opacity(0.3)))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .onChange(of: title) { viewModel.updateBlockTitle($0, for: block) }
                Spacer()
                // Progress
                let done = items.filter(\.isChecked).count
                if !items.isEmpty {
                    Text("\(done)/\(items.count)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                }
                blockMenu
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 10)

            if !items.isEmpty {
                Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 14)
                VStack(spacing: 0) {
                    ForEach(items) { checkRow($0) }
                }
            }

            Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 14)

            // Inline add field
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: category.colorHex1).opacity(0.55))
                TextField("", text: $newItemText,
                          prompt: Text("Lägg till…").foregroundColor(.white.opacity(0.22)))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white)
                    .focused($addFieldFocused)
                    .onSubmit { submitItem() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func checkRow(_ item: TripCheckItem) -> some View {
        HStack(spacing: 12) {
            Button { Task { await viewModel.toggleCheckItem(item) } } label: {
                ZStack {
                    Circle()
                        .strokeBorder(
                            item.isChecked ? Color(hex: category.colorHex1) : Color.white.opacity(0.2),
                            lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if item.isChecked {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: category.colorHex1), Color(hex: category.colorHex2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 16, height: 16)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            Text(item.title)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(item.isChecked ? .white.opacity(0.28) : .white.opacity(0.85))
                .strikethrough(item.isChecked, color: .white.opacity(0.18))
            Spacer()
            Button { Task { await viewModel.deleteCheckItem(item) } } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.18))
                    .padding(8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .animation(.spring(response: 0.25), value: item.isChecked)
    }

    private func submitItem() {
        let t = newItemText.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        newItemText = ""
        Task { await viewModel.addCheckItem(title: t, to: block) }
    }

    private var blockMenu: some View {
        Menu {
            Button(role: .destructive) {
                Task { await viewModel.deleteBlock(block) }
            } label: { Label("Ta bort sektion", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.28))
                .padding(8)
        }
    }
}
