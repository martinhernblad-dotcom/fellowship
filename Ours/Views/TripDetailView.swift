import FirebaseFirestore
import PhotosUI
import SwiftUI

// MARK: - Trip Detail (block-based layout for Resor)

struct TripDetailView: View {
    let trip: OursSubcategory
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showAddBlock = false
    @State private var editMode: EditMode = .inactive
    @State private var showShoppingSheet = false
    @State private var subToRename: OursSubcategory? = nil
    @State private var renameText = ""

    private var blocks: [TripBlock] {
        viewModel.blocksByTrip[trip.id] ?? []
    }

    private var children: [OursSubcategory] {
        viewModel.childSubcategories(of: trip)
    }

    private var liveTrip: OursSubcategory {
        viewModel.subcategoriesByCategory[trip.categoryID]?
            .first(where: { $0.id == trip.id }) ?? trip
    }

    private var portions: Int { max(liveTrip.portions, 1) }

    private var isRecept: Bool {
        category.id == UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
    }

    private var canNest: Bool { category.allowsNestedSubcategories }

    private var hasContent: Bool {
        !blocks.isEmpty || (canNest && !children.isEmpty)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea(.container)
            if hasContent { blockList } else { emptyState }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !blocks.isEmpty || (canNest && !children.isEmpty) {
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
        .sheet(isPresented: $showShoppingSheet) {
            ShoppingListPickerSheet(
                ingredientBlocks: blocks.filter { $0.type == .checklist },
                trip: trip
            ).environmentObject(viewModel)
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
        .task { await viewModel.loadBlocks(for: trip) }
    }


    // MARK: - Block list

    private var blockList: some View {
        List {
            if isRecept {
                recipeControlsRow
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
            }

            if canNest && !children.isEmpty {
                Section {
                    ForEach(children) { child in
                        childRow(child)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteSubcategory(child, from: category) }
                                } label: {
                                    Label("Ta bort", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                    }
                    .onMove { from, to in
                        viewModel.moveSubcategory(in: category, parentID: trip.id,
                                                  fromOffsets: from, toOffset: to)
                    }
                } header: {
                    childSectionHeader
                }
            }

            ForEach(blocks) { block in
                Group {
                    switch block.type {
                    case .note:         NoteBlockCard(block: block, category: category)
                    case .checklist:    ChecklistBlockCard(block: block, category: category)
                    case .photos:       PhotoBlockCard(block: block, category: category)
                    case .list:         ListBlockCard(block: block, category: category)
                    case .monthlyCosts: MonthlyCostsBlockCard(block: block, category: category)
                    case .budget:       BudgetBlockCard(block: block, category: category)
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

    private var childSectionHeader: some View {
        Text("KATEGORIER")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.4))
            .tracking(1.0)
            .padding(.leading, 4)
    }

    @ViewBuilder
    private func childRow(_ child: OursSubcategory) -> some View {
        NavigationLink {
            TripDetailView(trip: child, category: category)
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

    // MARK: - Recipe controls bar

    private var accent: Color { Color(hex: category.colorHex1) }

    private var recipeControlsRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Portioner")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                Button {
                    if portions > 1 { viewModel.updateRecipePortions(portions - 1, for: liveTrip) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(portions > 1 ? accent : .white.opacity(0.15))
                }
                .buttonStyle(.plain)
                Text("\(portions)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: 20, alignment: .center)
                Button {
                    viewModel.updateRecipePortions(portions + 1, for: liveTrip)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(accent)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button { showShoppingSheet = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "cart.badge.plus")
                    Text("Inköpslista")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundColor(accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "plus.square.dashed")
                .font(.system(size: 52))
                .foregroundColor(Color(hex: category.colorHex1).opacity(0.4))
            Text(isRecept ? "Bygg ditt recept" : "Starta din resa")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            Text(isRecept
                 ? "Lägg till ingredienser,\ninstruktioner och foton."
                 : "Lägg till checklistor och anteckningar\nsom flyginformation, boende och mer.")
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
                    .onChange(of: title) { _, v in viewModel.updateBlockTitle(v, for: block) }
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
                    .frame(minHeight: 72, maxHeight: 400)
                    .onChange(of: text) { _, v in viewModel.updateBlockText(v, for: block) }
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
    @State private var swipeOffsets: [UUID: CGFloat] = [:]

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
                    .onChange(of: title) { _, v in viewModel.updateBlockTitle(v, for: block) }
                Spacer()
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
        let offset = swipeOffsets[item.id] ?? 0
        ZStack(alignment: .trailing) {
            // Delete background (revealed on left swipe)
            if offset < -8 {
                Color(red: 0.78, green: 0.22, blue: 0.22)
                    .overlay(
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(offset < -44 ? 1.0 : 0.5))
                            .padding(.trailing, 18),
                        alignment: .trailing
                    )
            }

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
                    .contentShape(Circle().size(CGSize(width: 32, height: 32)))
                }
                .buttonStyle(.plain)

                TextField(
                    "",
                    text: Binding(
                        get: { item.title },
                        set: { viewModel.updateCheckItemTitle($0, for: item) }
                    ),
                    prompt: Text("Tom").foregroundColor(.white.opacity(0.2))
                )
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(item.isChecked ? .white.opacity(0.28) : .white.opacity(0.85))
                .strikethrough(item.isChecked, color: .white.opacity(0.18))

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.cardBackground)
            .offset(x: offset)
            .animation(.spring(response: 0.25), value: item.isChecked)
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onChanged { val in
                        let dx = val.translation.width
                        let dy = val.translation.height
                        guard abs(dx) > abs(dy) * 1.1 else { return }
                        withAnimation(.interactiveSpring()) {
                            swipeOffsets[item.id] = dx < 0 ? max(dx, -80) : min(dx, 55)
                        }
                    }
                    .onEnded { val in
                        let dx = val.translation.width
                        if dx < -55 {
                            withAnimation(.easeOut(duration: 0.18)) {
                                swipeOffsets[item.id] = -400
                            }
                            Task {
                                try? await Task.sleep(for: .milliseconds(200))
                                await viewModel.deleteCheckItem(item)
                                swipeOffsets.removeValue(forKey: item.id)
                            }
                        } else if dx > 30 {
                            Task { await viewModel.toggleCheckItem(item) }
                            withAnimation(.spring(response: 0.3)) { swipeOffsets[item.id] = 0 }
                        } else {
                            withAnimation(.spring(response: 0.3)) { swipeOffsets[item.id] = 0 }
                        }
                    }
            )
        }
        .clipped()
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

// MARK: - Photo Block Card

struct PhotoBlockCard: View {
    let block: TripBlock
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoading = false
    @State private var fullScreenIndex: Int? = nil

    private var photoURLs: [URL] { viewModel.photoURLs(for: block) }

    private let maxPhotos = 3

    private var columnCount: Int {
        switch photoURLs.count {
        case 0: return 1
        case 1: return 2
        default: return 3
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            photoGrid

            // Floating ... menu — only visible when photos present
            if !photoURLs.isEmpty {
                Menu {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteBlock(block) }
                    } label: { Label("Ta bort sektion", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(10)
                }
            }
        }
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            isLoading = true
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await viewModel.addPhoto(data, to: block)
                    }
                }
                pickerItems = []
                isLoading = false
            }
        }
        .fullScreenCover(item: Binding(
            get: { fullScreenIndex.map { PhotoViewerItem(index: $0) } },
            set: { fullScreenIndex = $0?.index }
        )) { item in
            PhotoFullScreenViewer(
                urls: photoURLs,
                startIndex: item.index,
                coupleID: viewModel.coupleID,
                onDismiss: { fullScreenIndex = nil }
            )
        }
    }

    @ViewBuilder
    private var photoGrid: some View {
        if photoURLs.isEmpty {
            // Empty state — the whole block is a tap target
            PhotosPicker(selection: $pickerItems, maxSelectionCount: maxPhotos,
                         matching: .images, photoLibrary: .shared()) {
                ZStack {
                    Color(white: 0.08)
                    VStack(spacing: 10) {
                        Image(systemName: "camera")
                            .font(.system(size: 32, weight: .ultraLight))
                            .foregroundColor(.white.opacity(0.2))
                        Text("Lägg till foton")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.18))
                    }
                }
                .frame(height: 110)
            }
            .buttonStyle(.plain)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount),
                spacing: 2
            ) {
                ForEach(Array(photoURLs.enumerated()), id: \.element.absoluteString) { idx, url in
                    photoCell(url: url, idx: idx)
                }
                if photoURLs.count < maxPhotos {
                    addCell
                }
            }
        }
    }

    @ViewBuilder
    private func photoCell(url: URL, idx: Int) -> some View {
        Button { fullScreenIndex = idx } label: {
            AsyncPhotoCell(url: url, coupleID: viewModel.coupleID)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                viewModel.removePhoto(url: url, from: block)
            } label: {
                Label("Ta bort foto", systemImage: "trash")
            }
        }
    }

    private var addCell: some View {
        PhotosPicker(selection: $pickerItems, maxSelectionCount: maxPhotos - photoURLs.count,
                     matching: .images, photoLibrary: .shared()) {
            ZStack {
                Color(white: 0.12)
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.65)
                        .tint(.white.opacity(0.4))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.25))
                }
            }
            .aspectRatio(1, contentMode: .fill)
        }
        .buttonStyle(.plain)
    }
}

private struct AsyncPhotoCell: View {
    let url: URL
    let coupleID: String?
    @State private var image: UIImage? = nil

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color(white: 0.12)
                        ProgressView()
                            .tint(.white.opacity(0.3))
                            .scaleEffect(0.7)
                    }
                }
            }
            .clipped()
            .task(id: url.absoluteString) {
                image = await loadPhotoImage(url: url, coupleID: coupleID)
            }
    }
}

@MainActor
private func loadPhotoImage(url: URL, coupleID: String?) async -> UIImage? {
    let localTask = Task.detached(priority: .userInitiated) {
        UIImage(contentsOfFile: url.path)
    }
    if let local = await localTask.value { return local }
    guard let coupleID else { return nil }
    let filename = url.lastPathComponent
    do {
        let doc = try await Firestore.firestore()
            .collection("couples").document(coupleID)
            .collection("photoBlobs").document(filename)
            .getDocument()
        guard let base64 = doc.data()?["data"] as? String,
              let data = Data(base64Encoded: base64) else { return nil }
        try? data.write(to: url, options: .atomic)
        return UIImage(data: data)
    } catch {
        return nil
    }
}

private struct ZoomablePhotoView: View {
    let url: URL
    let coupleID: String?
    @State private var image: UIImage? = nil
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .contentShape(Rectangle())
                        .gesture(magnification)
                        .simultaneousGesture(panGesture)
                        .onTapGesture(count: 2) { handleDoubleTap() }
                } else {
                    Color.clear
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
        .task(id: url.absoluteString) {
            image = await loadPhotoImage(url: url, coupleID: coupleID)
        }
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 0.7), maxScale)
            }
            .onEnded { _ in
                if scale < minScale {
                    withAnimation(.spring(response: 0.3)) {
                        scale = minScale
                        offset = .zero
                        lastOffset = .zero
                    }
                }
                lastScale = max(scale, minScale)
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: scale > 1 ? 0 : 1000)
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func handleDoubleTap() {
        withAnimation(.spring(response: 0.3)) {
            if scale > 1 {
                scale = 1; lastScale = 1
                offset = .zero; lastOffset = .zero
            } else {
                scale = 2.5; lastScale = 2.5
            }
        }
    }
}

private struct PhotoViewerItem: Identifiable {
    let id = UUID()
    let index: Int
}

private struct PhotoFullScreenViewer: View {
    let urls: [URL]
    let startIndex: Int
    let coupleID: String?
    let onDismiss: () -> Void
    @State private var currentIndex: Int

    init(urls: [URL], startIndex: Int, coupleID: String?, onDismiss: @escaping () -> Void) {
        self.urls = urls; self.startIndex = startIndex; self.coupleID = coupleID
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(urls.enumerated()), id: \.element.absoluteString) { idx, url in
                    ZoomablePhotoView(url: url, coupleID: coupleID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .always : .never))
            .ignoresSafeArea()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white, Color.black.opacity(0.45))
                    .padding(20)
            }
        }
        .onTapGesture { onDismiss() }
    }
}

// MARK: - List Block Card (bullet list, no checkboxes)

struct ListBlockCard: View {
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

    private var items: [TripCheckItem] { viewModel.checkItemsByBlock[block.id] ?? [] }
    private var accent: Color { Color(hex: category.colorHex1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(accent.opacity(0.8))
                TextField("", text: $title,
                          prompt: Text("Rubrik").foregroundColor(.white.opacity(0.3)))
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.white)
                    .onChange(of: title) { _, v in viewModel.updateBlockTitle(v, for: block) }
                Spacer()
                blockMenu
            }
            .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 10)

            if !items.isEmpty {
                Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 14)
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            Circle().fill(accent.opacity(0.5)).frame(width: 5, height: 5)
                            TextField(
                                "",
                                text: Binding(
                                    get: { item.title },
                                    set: { viewModel.updateCheckItemTitle($0, for: item) }
                                ),
                                prompt: Text("Tom").foregroundColor(.white.opacity(0.2))
                            )
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            Spacer()
                            Button { Task { await viewModel.deleteCheckItem(item) } } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.18))
                                    .padding(8)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                    }
                }
            }

            Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 14)

            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 12)).foregroundColor(accent.opacity(0.55))
                TextField("", text: $newItemText,
                          prompt: Text("Lägg till…").foregroundColor(.white.opacity(0.22)))
                    .font(.system(size: 14, design: .rounded)).foregroundColor(.white)
                    .focused($addFieldFocused).onSubmit { submitItem() }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.28)).padding(8)
        }
    }
}

// MARK: - Budget Block Card (visual expandable spending overview)

struct BudgetBlockCard: View {
    let block: TripBlock
    let category: OursCategory
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var title: String
    @State private var text: String
    @State private var expanded: Set<String> = []

    init(block: TripBlock, category: OursCategory) {
        self.block = block; self.category = category
        _title = State(initialValue: block.title)
        _text  = State(initialValue: block.text)
    }

    // One color per section slot — warm palette matching Ekonomi accent
    private let sectionColors: [Color] = [
        Color(hex: "D39C5A"),
        Color(hex: "C07840"),
        Color(hex: "D4AF6A"),
        Color(hex: "9A7840"),
        Color(hex: "707860"),
        Color(hex: "4A9068"),
    ]
    private var accent: Color { Color(hex: category.colorHex1) }

    private struct BudgetSection: Identifiable {
        let id: String
        let name: String
        let items: [(label: String, amount: Double, isDeduction: Bool)]
        var net: Double { items.reduce(0) { $0 + ($1.isDeduction ? -$1.amount : $1.amount) } }
        var isSavings: Bool { name == "Sparande" }
        var isIncome:  Bool { name == "Inkomst" }
    }

    private var sections: [BudgetSection] {
        var result: [BudgetSection] = []
        var currentName = ""
        var currentItems: [(String, Double, Bool)] = []
        for line in text.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("## ") {
                if !currentName.isEmpty {
                    result.append(BudgetSection(id: currentName, name: currentName, items: currentItems))
                }
                currentName = String(t.dropFirst(3)); currentItems = []
            } else if t.contains(":") {
                let parts = t.components(separatedBy: ":")
                guard parts.count >= 2 else { continue }
                let label = parts[0].trimmingCharacters(in: .whitespaces)
                let raw = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: " ", with: "")
                let isDeduction = raw.hasPrefix("-")
                if let amt = Double(raw.replacingOccurrences(of: "-", with: "")), !label.isEmpty {
                    currentItems.append((label, amt, isDeduction))
                }
            }
        }
        if !currentName.isEmpty {
            result.append(BudgetSection(id: currentName, name: currentName, items: currentItems))
        }
        return result
    }

    private var spendingSections: [BudgetSection] {
        sections.filter { !$0.isSavings && !$0.isIncome }
    }
    private var savingsSection:   BudgetSection?   { sections.first { $0.isSavings } }
    private var incomeSection:    BudgetSection?   { sections.first { $0.isIncome } }
    private var grandTotal: Double { spendingSections.reduce(0) { $0 + $1.net } }
    private var savingsTotal: Double { savingsSection?.net ?? 0 }
    private var incomeTotal:  Double { incomeSection?.net ?? 0 }
    private var surplus:      Double { incomeTotal - grandTotal - savingsTotal }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accent.opacity(0.8))
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                budgetMenu
            }
            .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 12)

            // ── Income + Surplus row (only when income exists) ────────────
            if incomeTotal > 0 {
                HStack(alignment: .bottom, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LÖN / MÅN")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                            .tracking(0.8)
                        Text(formatKr(incomeTotal))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ÖVERSKOTT")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(surplusColor.opacity(0.7))
                            .tracking(0.8)
                        Text(surplusText)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(surplusColor)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 12)
            }

            // ── Summary row ─────────────────────────────────────────────────
            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LÖPANDE / MÅN")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(0.8)
                    Text(formatKr(grandTotal))
                        .font(.system(size: incomeTotal > 0 ? 20 : 26,
                                      weight: incomeTotal > 0 ? .semibold : .bold,
                                      design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SPARANDE")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "5A9068").opacity(0.7))
                        .tracking(0.8)
                    Text(formatKr(savingsTotal))
                        .font(.system(size: incomeTotal > 0 ? 18 : 20,
                                      weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "5A9068"))
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 14)

            // ── Segmented proportion bar ────────────────────────────────────
            if grandTotal > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(Array(spendingSections.enumerated()), id: \.element.id) { idx, sec in
                            let w = max(geo.size.width * CGFloat(sec.net / grandTotal), 4)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(sectionColors[min(idx, sectionColors.count - 1)])
                                .frame(width: w)
                        }
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 16).padding(.bottom, 16)
            }

            Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 14)

            // ── Category rows ───────────────────────────────────────────────
            VStack(spacing: 0) {
                ForEach(Array(spendingSections.enumerated()), id: \.element.id) { idx, sec in
                    categoryRow(sec, color: sectionColors[min(idx, sectionColors.count - 1)])
                }
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // ── Category row ─────────────────────────────────────────────────────────
    @ViewBuilder
    private func categoryRow(_ section: BudgetSection, color: Color) -> some View {
        let isExpanded = expanded.contains(section.id)
        let proportion = grandTotal > 0 ? CGFloat(section.net / grandTotal) : 0

        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if isExpanded { expanded.remove(section.id) } else { expanded.insert(section.id) }
                }
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 10) {
                        Circle().fill(color).frame(width: 7, height: 7)
                        Text(section.name)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text(formatKr(section.net))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.2))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.65))
                                .frame(width: geo.size.width * proportion)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── Sub-items ─────────────────────────────────────────────────
            if isExpanded {
                let maxAmt = section.items.filter { !$0.isDeduction }.map(\.amount).max() ?? 1
                VStack(spacing: 0) {
                    ForEach(section.items, id: \.label) { item in
                        subItemRow(item, color: color, maxAmt: maxAmt)
                    }
                    // Net line if there are deductions
                    if section.items.contains(where: { $0.isDeduction }) {
                        Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                        HStack {
                            Text("Netto")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.45))
                            Spacer()
                            Text(formatKr(section.net))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(color)
                        }
                        .padding(.leading, 32).padding(.trailing, 16).padding(.vertical, 8)
                    }
                }
                .background(Color.white.opacity(0.025))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 14)
        }
    }

    // ── Sub-item row ─────────────────────────────────────────────────────────
    @ViewBuilder
    private func subItemRow(_ item: (label: String, amount: Double, isDeduction: Bool),
                             color: Color, maxAmt: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.label)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(item.isDeduction ? Color(hex: "5A9068").opacity(0.85) : .white.opacity(0.55))
                Spacer()
                Text(item.isDeduction ? "−\(formatKr(item.amount))" : formatKr(item.amount))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(item.isDeduction ? Color(hex: "5A9068").opacity(0.85) : .white.opacity(0.4))
            }
            if !item.isDeduction {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color.opacity(0.3))
                        .frame(width: geo.size.width * CGFloat(item.amount / maxAmt), height: 2.5)
                }
                .frame(height: 2.5)
            }
        }
        .padding(.leading, 32).padding(.trailing, 16).padding(.vertical, 7)
    }

    private var surplusColor: Color {
        if surplus > 0 { return Color(hex: "5A9068") }
        if surplus < 0 { return Color(red: 0.85, green: 0.40, blue: 0.35) }
        return .white.opacity(0.55)
    }

    private var surplusText: String {
        let sign = surplus > 0 ? "+" : (surplus < 0 ? "−" : "")
        return sign + formatKr(abs(surplus))
    }

    // ── Helpers ──────────────────────────────────────────────────────────────
    private func formatKr(_ value: Double) -> String {
        let n = Int(value.rounded())
        var result = ""; var s = String(n)
        for (i, c) in s.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { result = " " + result }
            result = String(c) + result
        }
        return result + " kr"
    }

    private var budgetMenu: some View {
        Menu {
            Button(role: .destructive) {
                Task { await viewModel.deleteBlock(block) }
            } label: { Label("Ta bort", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.28)).padding(8)
        }
    }
}

// MARK: - Monthly Costs Block Card

struct MonthlyCostsBlockCard: View {
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

    private var accent: Color { Color(hex: category.colorHex1) }

    private struct CostRow: Identifiable {
        let id = UUID()
        let label: String
        let amount: String
        let isTotal: Bool
    }

    private var parsedRows: [CostRow] {
        text.components(separatedBy: "\n").compactMap { line in
            let parts = line.components(separatedBy: ":")
            guard parts.count >= 2 else { return nil }
            let label  = parts[0].trimmingCharacters(in: .whitespaces)
            let amount = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
            guard !label.isEmpty, !amount.isEmpty else { return nil }
            return CostRow(label: label, amount: amount,
                           isTotal: label.lowercased().hasPrefix("total"))
        }
    }

    private var monthHeader: String? {
        guard let first = text.components(separatedBy: "\n").first?
            .trimmingCharacters(in: .whitespaces),
              !first.isEmpty, !first.contains(":") else { return nil }
        return first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(accent.opacity(0.8))
                TextField("", text: $title,
                          prompt: Text("Rubrik").foregroundColor(.white.opacity(0.3)))
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.white)
                    .onChange(of: title) { _, v in viewModel.updateBlockTitle(v, for: block) }
                Spacer()
                blockMenu
            }
            .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 10)

            Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 14)

            if parsedRows.isEmpty {
                Text("Klistra in månadssammanfattning…")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.22))
                    .padding(14)
            } else {
                if let month = monthHeader {
                    Text(month)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(accent)
                        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
                }
                VStack(spacing: 0) {
                    ForEach(parsedRows) { row in
                        HStack {
                            Text(row.label)
                                .font(.system(size: row.isTotal ? 14 : 13,
                                              weight: row.isTotal ? .semibold : .regular,
                                              design: .rounded))
                                .foregroundColor(row.isTotal ? .white : .white.opacity(0.7))
                            Spacer()
                            Text(row.amount)
                                .font(.system(size: row.isTotal ? 14 : 13,
                                              weight: row.isTotal ? .semibold : .regular,
                                              design: .rounded))
                                .foregroundColor(row.isTotal ? accent : .white.opacity(0.55))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        if row.isTotal {
                            Divider().background(Color.white.opacity(0.07)).padding(.horizontal, 14)
                        }
                    }
                }
                .padding(.bottom, 6)
            }

            Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 14)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60, maxHeight: 300)
                    .onChange(of: text) { _, v in viewModel.updateBlockText(v, for: block) }
                if text.isEmpty {
                    Text("Klistra in text här…")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.15))
                        .padding(.top, 8).padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
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
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.28)).padding(8)
        }
    }
}

// MARK: - Shopping List Picker Sheet

struct ShoppingListPickerSheet: View {
    let ingredientBlocks: [TripBlock]
    let trip: OursSubcategory
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var isAdding = false

    private let shoppingCatID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var shoppingLists: [OursSubcategory] {
        viewModel.subcategoriesByCategory[shoppingCatID] ?? []
    }

    private var ingredients: [String] {
        ingredientBlocks.flatMap { block in
            (viewModel.checkItemsByBlock[block.id] ?? [])
                .filter { !$0.isChecked }
                .map { $0.title }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea(.container)

                if isLoading {
                    ProgressView().tint(.white)
                } else if shoppingLists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cart")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.2))
                        Text("Inga inköpslistor hittades")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Skapa en lista under Shopping först.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.25))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("\(ingredients.count) ingredienser (ej ikryssade)")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 20)

                        VStack(spacing: 8) {
                            ForEach(shoppingLists) { list in
                                Button {
                                    guard !isAdding else { return }
                                    isAdding = true
                                    Task {
                                        await viewModel.addItemsToList(
                                            titles: ingredients,
                                            subcategoryID: list.id
                                        )
                                        dismiss()
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 9)
                                                .fill(Color(hex: "D08A62").opacity(0.18))
                                                .frame(width: 36, height: 36)
                                            Image(systemName: list.iconName)
                                                .font(.system(size: 16))
                                                .foregroundColor(Color(hex: "D08A62"))
                                        }
                                        Text(list.name)
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                        Spacer()
                                        if isAdding {
                                            ProgressView().tint(.white.opacity(0.4))
                                        } else {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.2))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Välj inköpslista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") { dismiss() }.foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if let cat = viewModel.categories.first(where: { $0.id == shoppingCatID }) {
                await viewModel.loadSubcategories(for: cat)
            }
            isLoading = false
        }
    }
}
