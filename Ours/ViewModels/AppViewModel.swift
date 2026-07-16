import FirebaseFirestore
import Foundation
import SwiftUI
import UIKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var categories:              [OursCategory]             = []
    @Published var subcategoriesByCategory: [UUID: [OursSubcategory]] = [:]
    @Published var itemsBySubcategory:      [UUID: [ListItem]]         = [:]
    @Published var profiles:               [UserProfile]              = []
    @Published var currentProfile:         UserProfile?
    @Published var blocksByTrip:           [UUID: [TripBlock]]        = [:]
    @Published var checkItemsByBlock:      [UUID: [TripCheckItem]]    = [:]
    @Published var coupleID:               String?
    @Published var isSyncing:              Bool                        = false
    @Published var lastSyncDate:           Date?
    @Published var undoSnapshot:           DeletedSnapshot?

    // Everything needed to restore the most recent deletion, kept for a short window.
    struct DeletedSnapshot: Equatable {
        struct PhotoFile: Equatable { let filename: String; let data: Data }
        let label: String
        let subcategories: [OursSubcategory]
        let items: [ListItem]
        let blocks: [TripBlock]
        let checkItems: [TripCheckItem]
        let photoFiles: [PhotoFile]
    }
    private var undoExpiryTask: Task<Void, Never>?

    let cloudKit = CloudKitService()

    private var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
    }

    var isProfileSetup: Bool { currentProfile != nil }

    var partnerProfile: UserProfile? {
        let myName = currentProfile?.name
        return profiles.first { profile in
            profile.deviceID != deviceID
                && (myName == nil || profile.name != myName)
        }
    }

    private var noteSaveTasks:  [UUID: Task<Void, Never>] = [:]
    private var blockSaveTasks: [UUID: Task<Void, Never>] = [:]

    init() {
        restoreLocalProfile()
        coupleID = cloudKit.coupleID
        cloudKit.onDataChanged = { [weak self] in self?.refreshFromStore() }
    }

    func refreshFromStore() {
        let store = LocalStore.shared

        var subsByCategory: [UUID: [OursSubcategory]] = [:]
        for s in store.subcategories.sorted(by: { $0.order < $1.order }) {
            subsByCategory[s.categoryID, default: []].append(s)
        }
        if subcategoriesByCategory != subsByCategory { subcategoriesByCategory = subsByCategory }

        var itemsBySub: [UUID: [ListItem]] = [:]
        for i in store.items.sorted(by: { $0.order < $1.order }) {
            itemsBySub[i.subcategoryID, default: []].append(i)
        }
        if itemsBySubcategory != itemsBySub { itemsBySubcategory = itemsBySub }

        var blocksByT: [UUID: [TripBlock]] = [:]
        for b in store.tripBlocks.sorted(by: { $0.order < $1.order }) {
            blocksByT[b.tripID, default: []].append(b)
        }
        if blocksByTrip != blocksByT { blocksByTrip = blocksByT }

        var ciByB: [UUID: [TripCheckItem]] = [:]
        for ci in store.tripCheckItems.sorted(by: { $0.order < $1.order }) {
            ciByB[ci.blockID, default: []].append(ci)
        }
        if checkItemsByBlock != ciByB { checkItemsByBlock = ciByB }

        if profiles != store.profiles { profiles = store.profiles }
        if !store.categories.isEmpty, categories != store.categories {
            categories = store.categories
        }

        if let myID = currentProfile?.deviceID,
           let mine = profiles.first(where: { $0.deviceID == myID }),
           mine != currentProfile {
            currentProfile = mine
        }
    }

    // MARK: - Profile

    private func restoreLocalProfile() {
        guard let name  = UserDefaults.standard.string(forKey: "profile_name"),
              let emoji = UserDefaults.standard.string(forKey: "profile_emoji")
        else { return }
        let idStr = UserDefaults.standard.string(forKey: "profile_id") ?? UUID().uuidString
        let id    = UUID(uuidString: idStr) ?? UUID()
        currentProfile = UserProfile(id: id, name: name, emoji: emoji, deviceID: deviceID)
    }

    func updateProfileEmoji(_ emoji: String) async {
        guard var profile = currentProfile else { return }
        profile.emoji = emoji
        UserDefaults.standard.set(emoji, forKey: "profile_emoji")
        currentProfile = profile
        _ = try? await cloudKit.saveProfile(profile)
    }

    func setupProfile(name: String, emoji: String) async {
        let id      = UUID()
        var profile = UserProfile(id: id, name: name, emoji: emoji, deviceID: deviceID)
        UserDefaults.standard.set(name,          forKey: "profile_name")
        UserDefaults.standard.set(emoji,         forKey: "profile_emoji")
        UserDefaults.standard.set(id.uuidString, forKey: "profile_id")
        currentProfile = profile
        profile = (try? await cloudKit.saveProfile(profile)) ?? profile
        currentProfile = profile
        profiles = (try? await cloudKit.fetchProfiles()) ?? [profile]
    }

    // MARK: - Pairing

    func createCoupleCode() async throws -> String {
        let code = try await cloudKit.createCoupleCode()
        coupleID = code
        await cloudKit.setupSubscriptions()
        if let profile = currentProfile {
            _ = try? await cloudKit.saveProfile(profile)
        }
        return code
    }

    func joinCouple(code: String) async throws -> Bool {
        let joined = try await cloudKit.joinCouple(code: code)
        if joined {
            coupleID = cloudKit.coupleID
            await cloudKit.setupSubscriptions()
            // Push our own data up (profile + anything we have locally) before pulling
            await cloudKit.pushAll()
            await syncFromCloud()
        }
        return joined
    }

    func syncFromCloud() async {
        isSyncing = true
        defer { isSyncing = false }
        try? await cloudKit.syncAll()
        categories = (try? await cloudKit.fetchCategories()) ?? OursCategory.seed
        profiles   = (try? await cloudKit.fetchProfiles())   ?? []
        for catID in subcategoriesByCategory.keys {
            if let cat = categories.first(where: { $0.id == catID }) {
                await loadSubcategories(for: cat)
            }
        }
        for subID in itemsBySubcategory.keys {
            for subs in subcategoriesByCategory.values {
                if let sub = subs.first(where: { $0.id == subID }) {
                    await loadItems(for: sub)
                }
            }
        }
        lastSyncDate = Date()
    }

    // MARK: - Load

    func loadAll() async {
        try? await cloudKit.seedCategoriesIfNeeded()
        categories = (try? await cloudKit.fetchCategories()) ?? OursCategory.seed
        profiles   = (try? await cloudKit.fetchProfiles())   ?? []
        if coupleID != nil {
            isSyncing = true
            try? await cloudKit.syncAll()
            profiles = (try? await cloudKit.fetchProfiles()) ?? profiles
            refreshFromStore()
            await cloudKit.setupSubscriptions()
            Task { await migratePhotosToCloudIfNeeded() }
            isSyncing = false
            lastSyncDate = Date()
        }
        await seedRecipesIfNeeded()
        await migrateBudgetIncomeIfNeeded()
    }

    func loadSubcategories(for category: OursCategory) async {
        subcategoriesByCategory[category.id] =
            (try? await cloudKit.fetchSubcategories(for: category.id)) ?? []
    }

    func loadItems(for subcategory: OursSubcategory) async {
        itemsBySubcategory[subcategory.id] =
            (try? await cloudKit.fetchItems(for: subcategory.id)) ?? []
    }

    func setupSync() async {
        await cloudKit.setupSubscriptions()
    }

    // MARK: - Subcategory CRUD

    func addSubcategory(name: String, iconName: String, note: String = "",
                        parentSubcategoryID: UUID? = nil,
                        isGroup: Bool = false,
                        to category: OursCategory) async {
        let siblings = (subcategoriesByCategory[category.id] ?? [])
            .filter { $0.parentSubcategoryID == parentSubcategoryID }
        let parentItems: Int = parentSubcategoryID.map { (itemsBySubcategory[$0]?.count) ?? 0 } ?? 0
        let parentBlocks: Int = parentSubcategoryID.map { (blocksByTrip[$0]?.count) ?? 0 } ?? 0
        let order = siblings.count + parentItems + parentBlocks
        let sub = OursSubcategory(name: name, iconName: iconName, order: order,
                                  categoryID: category.id, note: note,
                                  parentSubcategoryID: parentSubcategoryID,
                                  isGroup: isGroup)
        subcategoriesByCategory[category.id, default: []].append(sub)
        _ = try? await cloudKit.saveSubcategory(sub)
    }

    func childSubcategories(of parent: OursSubcategory) -> [OursSubcategory] {
        (subcategoriesByCategory[parent.categoryID] ?? [])
            .filter { $0.parentSubcategoryID == parent.id }
            .sorted { $0.order < $1.order }
    }

    func updateRecipePortions(_ portions: Int, for sub: OursSubcategory) {
        let clamped = max(1, portions)
        guard let idx = subcategoriesByCategory[sub.categoryID]?
            .firstIndex(where: { $0.id == sub.id }) else { return }
        subcategoriesByCategory[sub.categoryID]?[idx].portions = clamped
        guard let updated = subcategoriesByCategory[sub.categoryID]?[idx] else { return }
        noteSaveTasks[sub.id]?.cancel()
        noteSaveTasks[sub.id] = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            _ = try? await cloudKit.saveSubcategory(updated)
        }
    }

    func updateNote(_ note: String, for subcategory: OursSubcategory, in category: OursCategory) {
        guard let idx = subcategoriesByCategory[category.id]?
            .firstIndex(where: { $0.id == subcategory.id }) else { return }
        subcategoriesByCategory[category.id]?[idx].note = note
        guard let updated = subcategoriesByCategory[category.id]?[idx] else { return }
        noteSaveTasks[subcategory.id]?.cancel()
        noteSaveTasks[subcategory.id] = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            _ = try? await cloudKit.saveSubcategory(updated)
        }
    }

    func deleteSubcategory(_ sub: OursSubcategory, from category: OursCategory) async {
        let snapshot = snapshotForSubcategories([sub], label: "\(sub.name) borttagen")
        let store = LocalStore.shared
        let descendants = store.descendantSubcategoryIDs(of: sub.id)
        let allIDs = Set([sub.id] + descendants)
        let photoBlocks = store.tripBlocks.filter {
            allIDs.contains($0.tripID) && $0.type == .photos
        }
        for block in photoBlocks { deletePhotoBlobs(in: block) }
        try? await cloudKit.deleteSubcategory(sub)
        subcategoriesByCategory[category.id]?.removeAll { $0.id == sub.id }
        itemsBySubcategory.removeValue(forKey: sub.id)
        offerUndo(snapshot)
    }

    // Bulk delete with a single combined undo (used by multi-select).
    func deleteSubcategories(_ subs: [OursSubcategory], from category: OursCategory) async {
        guard !subs.isEmpty else { return }
        let label = subs.count == 1 ? "\(subs[0].name) borttagen" : "\(subs.count) borttagna"
        let snapshot = snapshotForSubcategories(subs, label: label)
        let store = LocalStore.shared
        for sub in subs {
            let allIDs = Set([sub.id] + store.descendantSubcategoryIDs(of: sub.id))
            let photoBlocks = store.tripBlocks.filter {
                allIDs.contains($0.tripID) && $0.type == .photos
            }
            for block in photoBlocks { deletePhotoBlobs(in: block) }
            try? await cloudKit.deleteSubcategory(sub)
            subcategoriesByCategory[category.id]?.removeAll { $0.id == sub.id }
            itemsBySubcategory.removeValue(forKey: sub.id)
        }
        offerUndo(snapshot)
    }

    func renameSubcategory(_ sub: OursSubcategory, to name: String, in category: OursCategory) {
        guard var subs = subcategoriesByCategory[category.id],
              let idx  = subs.firstIndex(where: { $0.id == sub.id }) else { return }
        subs[idx].name = name
        subcategoriesByCategory[category.id] = subs
        Task { try? await cloudKit.saveSubcategory(subs[idx]) }
    }

    func moveSubcategory(in category: OursCategory,
                         parentID: UUID? = nil,
                         fromOffsets: IndexSet, toOffset: Int) {
        guard var allSubs = subcategoriesByCategory[category.id] else { return }
        var siblings = allSubs
            .filter { $0.parentSubcategoryID == parentID }
            .sorted { $0.order < $1.order }
        siblings.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for i in siblings.indices { siblings[i].order = i }
        for s in siblings {
            if let idx = allSubs.firstIndex(where: { $0.id == s.id }) { allSubs[idx] = s }
        }
        subcategoriesByCategory[category.id] = allSubs
        Task { for s in siblings { _ = try? await cloudKit.saveSubcategory(s) } }
    }

    // MARK: - Undo (ångra)

    private func snapshotForSubcategories(_ subs: [OursSubcategory], label: String) -> DeletedSnapshot {
        let store = LocalStore.shared
        var allIDs = Set<UUID>()
        for sub in subs {
            allIDs.insert(sub.id)
            allIDs.formUnion(store.descendantSubcategoryIDs(of: sub.id))
        }
        let subcategories = store.subcategories.filter { allIDs.contains($0.id) }
        let items         = store.items.filter { allIDs.contains($0.subcategoryID) }
        let blocks        = store.tripBlocks.filter { allIDs.contains($0.tripID) }
        let blockIDs      = Set(blocks.map(\.id))
        let checkItems    = store.tripCheckItems.filter { blockIDs.contains($0.blockID) }
        return DeletedSnapshot(label: label,
                               subcategories: subcategories, items: items,
                               blocks: blocks, checkItems: checkItems,
                               photoFiles: capturePhotoFiles(for: blocks))
    }

    private func capturePhotoFiles(for blocks: [TripBlock]) -> [DeletedSnapshot.PhotoFile] {
        let dir = photosDirectory()
        return blocks
            .filter { $0.type == .photos }
            .flatMap { block -> [DeletedSnapshot.PhotoFile] in
                guard let names = try? JSONDecoder().decode([String].self, from: Data(block.text.utf8))
                else { return [] }
                return names.compactMap { name in
                    (try? Data(contentsOf: dir.appendingPathComponent(name)))
                        .map { DeletedSnapshot.PhotoFile(filename: name, data: $0) }
                }
            }
    }

    private func offerUndo(_ snapshot: DeletedSnapshot) {
        undoExpiryTask?.cancel()
        withAnimation(.spring(duration: 0.3)) { undoSnapshot = snapshot }
        undoExpiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { self?.undoSnapshot = nil }
        }
    }

    func undoLastDelete() async {
        guard let snap = undoSnapshot else { return }
        undoExpiryTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { undoSnapshot = nil }

        // Clear tombstones first so a concurrent sync can't re-delete what we restore.
        for s in snap.subcategories { cloudKit.removeTombstone("subcategories",  id: s.id.uuidString) }
        for i in snap.items         { cloudKit.removeTombstone("items",          id: i.id.uuidString) }
        for b in snap.blocks        { cloudKit.removeTombstone("tripBlocks",     id: b.id.uuidString) }
        for c in snap.checkItems    { cloudKit.removeTombstone("tripCheckItems", id: c.id.uuidString) }

        // Restore photo files locally and re-upload their blobs.
        let dir = photosDirectory()
        for photo in snap.photoFiles {
            try? photo.data.write(to: dir.appendingPathComponent(photo.filename), options: .atomic)
            if let cid = cloudKit.coupleID {
                let base64 = photo.data.base64EncodedString()
                let filename = photo.filename
                Task.detached {
                    _ = try? await Firestore.firestore()
                        .collection("couples").document(cid)
                        .collection("photoBlobs").document(filename)
                        .setData(["data": base64])
                }
            }
        }

        // Re-save entities: merges into the local store and pushes to Firestore.
        for s in snap.subcategories { _ = try? await cloudKit.saveSubcategory(s) }
        for i in snap.items         { _ = try? await cloudKit.saveItem(i) }
        for b in snap.blocks        { _ = try? await cloudKit.saveBlock(b) }
        for c in snap.checkItems    { _ = try? await cloudKit.saveCheckItem(c) }

        refreshFromStore()
    }

    // MARK: - Item CRUD

    func addItem(title: String, notes: String, url: String, to sub: OursSubcategory) async {
        let childCount = (subcategoriesByCategory[sub.categoryID] ?? [])
            .filter { $0.parentSubcategoryID == sub.id }.count
        let itemCount = itemsBySubcategory[sub.id]?.count ?? 0
        let blockCount = blocksByTrip[sub.id]?.count ?? 0
        let order = childCount + itemCount + blockCount
        let item = ListItem(title: title, notes: notes, url: url, order: order,
                            subcategoryID: sub.id)
        itemsBySubcategory[sub.id, default: []].append(item)
        _ = try? await cloudKit.saveItem(item)
    }

    func toggleItem(_ item: ListItem, in sub: OursSubcategory) async {
        var updated = item
        updated.isCompleted.toggle()
        updated = (try? await cloudKit.saveItem(updated)) ?? updated
        if let idx = itemsBySubcategory[sub.id]?.firstIndex(where: { $0.id == item.id }) {
            itemsBySubcategory[sub.id]?[idx] = updated
        }
    }

    func deleteItem(_ item: ListItem, from sub: OursSubcategory) async {
        try? await cloudKit.deleteItem(item)
        itemsBySubcategory[sub.id]?.removeAll { $0.id == item.id }
        offerUndo(DeletedSnapshot(label: "\(item.title) borttagen",
                                  subcategories: [], items: [item],
                                  blocks: [], checkItems: [], photoFiles: []))
    }

    func renameItem(_ item: ListItem, to name: String, in sub: OursSubcategory) {
        guard var its = itemsBySubcategory[sub.id],
              let idx = its.firstIndex(where: { $0.id == item.id }) else { return }
        its[idx].title = name
        itemsBySubcategory[sub.id] = its
        Task { _ = try? await cloudKit.saveItem(its[idx]) }
    }

    func updateItem(_ item: ListItem, title: String, notes: String, url: String, in sub: OursSubcategory) {
        guard var its = itemsBySubcategory[sub.id],
              let idx = its.firstIndex(where: { $0.id == item.id }) else { return }
        its[idx].title = title
        its[idx].notes = notes
        its[idx].url   = url
        itemsBySubcategory[sub.id] = its
        Task { _ = try? await cloudKit.saveItem(its[idx]) }
    }

    func moveItem(in subcategory: OursSubcategory, fromOffsets: IndexSet, toOffset: Int) {
        guard var its = itemsBySubcategory[subcategory.id] else { return }
        its.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for i in its.indices { its[i].order = i }
        itemsBySubcategory[subcategory.id] = its
        Task { for item in its { _ = try? await cloudKit.saveItem(item) } }
    }

    func moveItem(_ item: ListItem, to destination: OursSubcategory) {
        // Remove from source and reindex
        var sourceItems = itemsBySubcategory[item.subcategoryID] ?? []
        sourceItems.removeAll { $0.id == item.id }
        for i in sourceItems.indices { sourceItems[i].order = i }
        itemsBySubcategory[item.subcategoryID] = sourceItems

        // Update item with new subcategory and append order
        var moved = item
        moved.subcategoryID = destination.id
        moved.order = (itemsBySubcategory[destination.id] ?? []).count
        itemsBySubcategory[destination.id, default: []].append(moved)

        Task {
            _ = try? await cloudKit.saveItem(moved)
            for i in sourceItems { _ = try? await cloudKit.saveItem(i) }
        }
    }

    func parentSubcategory(of sub: OursSubcategory) -> OursSubcategory? {
        guard let parentID = sub.parentSubcategoryID else { return nil }
        return (subcategoriesByCategory[sub.categoryID] ?? []).first { $0.id == parentID }
    }

    func updateSubcategoryOrder(_ id: UUID, in category: OursCategory, to newOrder: Int) {
        guard let idx = subcategoriesByCategory[category.id]?.firstIndex(where: { $0.id == id }) else { return }
        guard subcategoriesByCategory[category.id]?[idx].order != newOrder else { return }
        subcategoriesByCategory[category.id]?[idx].order = newOrder
        if let updated = subcategoriesByCategory[category.id]?[idx] {
            Task { _ = try? await cloudKit.saveSubcategory(updated) }
        }
    }

    func updateItemOrder(_ id: UUID, in subcategory: OursSubcategory, to newOrder: Int) {
        guard let idx = itemsBySubcategory[subcategory.id]?.firstIndex(where: { $0.id == id }) else { return }
        guard itemsBySubcategory[subcategory.id]?[idx].order != newOrder else { return }
        itemsBySubcategory[subcategory.id]?[idx].order = newOrder
        if let updated = itemsBySubcategory[subcategory.id]?[idx] {
            Task { _ = try? await cloudKit.saveItem(updated) }
        }
    }

    func updateBlockOrder(_ id: UUID, in trip: OursSubcategory, to newOrder: Int) {
        guard let idx = blocksByTrip[trip.id]?.firstIndex(where: { $0.id == id }) else { return }
        guard blocksByTrip[trip.id]?[idx].order != newOrder else { return }
        blocksByTrip[trip.id]?[idx].order = newOrder
        if let updated = blocksByTrip[trip.id]?[idx] {
            Task { _ = try? await cloudKit.saveBlock(updated) }
        }
    }

    func loadAllSubcategories() async {
        for cat in categories where subcategoriesByCategory[cat.id] == nil {
            await loadSubcategories(for: cat)
        }
    }

    func addItemsToList(titles: [String], subcategoryID: UUID) async {
        let target = subcategoriesByCategory.values.flatMap { $0 }.first { $0.id == subcategoryID }
        let childCount = (target.flatMap { sub in
            (subcategoriesByCategory[sub.categoryID] ?? [])
                .filter { $0.parentSubcategoryID == sub.id }.count
        }) ?? 0
        var order = childCount + (itemsBySubcategory[subcategoryID]?.count ?? 0)
        for title in titles {
            var item = ListItem(title: title, order: order, subcategoryID: subcategoryID)
            item = (try? await cloudKit.saveItem(item)) ?? item
            itemsBySubcategory[subcategoryID, default: []].append(item)
            order += 1
        }
    }

    // MARK: - Trip Block CRUD

    func createEkonomiSectionsIfNeeded() async {
        let ekonomiID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        guard let cat = categories.first(where: { $0.id == ekonomiID }) else { return }
        await loadSubcategories(for: cat)
        guard (subcategoriesByCategory[ekonomiID] ?? []).isEmpty else { return }
        let myName      = currentProfile?.name  ?? "Jag"
        let partnerName = partnerProfile?.name  ?? "Partner"
        let sections    = [(myName, "person.fill"), (partnerName, "person.fill"), ("Gemensam", "person.2.fill")]
        for (_, (name, icon)) in sections.enumerated() {
            await addSubcategory(name: name, iconName: icon, to: cat)
        }
    }

    func loadBlocks(for trip: OursSubcategory) async {
        let blocks = (try? await cloudKit.fetchBlocks(for: trip.id)) ?? []
        blocksByTrip[trip.id] = blocks
        for block in blocks where block.type == .checklist || block.type == .list {
            checkItemsByBlock[block.id] = (try? await cloudKit.fetchCheckItems(for: block.id)) ?? []
        }
        // Auto-migrate Recept from old flat format to blocks on first open
        let receptID = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
        if blocks.isEmpty, trip.categoryID == receptID {
            await migrateRecipeToBlocks(trip)
        }
        // Auto-seed budget block for the current user's Ekonomi section
        let ekonomiID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let isMyEkonomiSection = trip.categoryID == ekonomiID &&
            trip.name == (currentProfile?.name ?? "")
        let hasBudget = blocks.contains { $0.type == .budget }
        // Budget data is hardcoded for Martin; only auto-seed on his device.
        if isMyEkonomiSection && !hasBudget && currentProfile?.name == "Martin" {
            await seedBudgetBlock(for: trip)
        }
    }

    private func seedBudgetBlock(for trip: OursSubcategory) async {
        let budgetText = """
## Inkomst
Lön (efter skatt): 50000
## Boende
Bolån (Stadshypotek): 10251
Hyra (Nabo 40): 5446
Förråd: 122
Julias andel: -5357
## Bil
Lease: 4488
Bränsle: 639
Parkering (fast): 1056
Parkering (rörlig): 266
Fordonsskatt: 793
Bilservice: 338
Julias andel: -1000
## Mat & dryck
Matbutik: 5213
Café (Josephine Bake): 385
Restaurang: 2650
Kafé & convenience: 143
Matleverans: 618
Bar & alkohol: 801
## Nöje
Golf: 3413
Keramik: 1918
Streaming: 894
Spel: 494
Shopping: 1181
## Fasta avgifter
Studielån (CSN): 1944
Fack & försäkring: 616
Välgörenhet: 50
Telefon: 262
## Sparande
Månadsspar: 7000
"""
        var block = TripBlock(tripID: trip.id, title: "Månadsbudget",
                              type: .budget, order: 0, text: budgetText)
        block = (try? await cloudKit.saveBlock(block)) ?? block
        blocksByTrip[trip.id, default: []].insert(block, at: 0)
    }

    private func migrateRecipeToBlocks(_ trip: OursSubcategory) async {
        var newBlocks: [TripBlock] = []

        var instrBlock = TripBlock(tripID: trip.id, title: "Instruktioner",
                                   type: .note, order: 0, text: trip.note)
        instrBlock = (try? await cloudKit.saveBlock(instrBlock)) ?? instrBlock
        newBlocks.append(instrBlock)

        var ingrBlock = TripBlock(tripID: trip.id, title: "Ingredienser",
                                  type: .checklist, order: 1)
        ingrBlock = (try? await cloudKit.saveBlock(ingrBlock)) ?? ingrBlock
        newBlocks.append(ingrBlock)

        let existingItems = (try? await cloudKit.fetchItems(for: trip.id)) ?? []
        var checkItems: [TripCheckItem] = []
        for (i, item) in existingItems.enumerated() {
            var ci = TripCheckItem(blockID: ingrBlock.id, title: item.title,
                                   isChecked: item.isCompleted, order: i)
            ci = (try? await cloudKit.saveCheckItem(ci)) ?? ci
            checkItems.append(ci)
        }
        checkItemsByBlock[ingrBlock.id] = checkItems
        blocksByTrip[trip.id] = newBlocks
    }

    // MARK: - Photo management

    private func photosDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("recipe_photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func photoURLs(for block: TripBlock) -> [URL] {
        guard let data = block.text.data(using: .utf8),
              let filenames = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        let dir = photosDirectory()
        return filenames.map { dir.appendingPathComponent($0) }
    }

    func addPhoto(_ data: Data, to block: TripBlock) async {
        guard let image = UIImage(data: data),
              let jpegData = compressForFirestore(image) else { return }

        let dir = photosDirectory()
        let filename = "\(block.id.uuidString)_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        let fileURL = dir.appendingPathComponent(filename)

        do { try jpegData.write(to: fileURL, options: .atomic) }
        catch { return }

        if let cid = cloudKit.coupleID {
            let base64 = jpegData.base64EncodedString()
            Task.detached {
                _ = try? await Firestore.firestore()
                    .collection("couples").document(cid)
                    .collection("photoBlobs").document(filename)
                    .setData(["data": base64])
            }
        }

        guard let idx = blocksByTrip[block.tripID]?.firstIndex(where: { $0.id == block.id }) else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        let existing = blocksByTrip[block.tripID]?[idx].text ?? ""
        var filenames = (try? JSONDecoder().decode([String].self, from: Data(existing.utf8))) ?? []
        filenames.append(filename)
        let newText = (try? String(data: JSONEncoder().encode(filenames), encoding: .utf8)) ?? ""
        blocksByTrip[block.tripID]?[idx].text = newText
        if let updated = blocksByTrip[block.tripID]?[idx] {
            _ = try? await cloudKit.saveBlock(updated)
        }
    }

    func removePhoto(url: URL, from block: TripBlock) {
        let filename = url.lastPathComponent
        try? FileManager.default.removeItem(at: url)

        if let cid = cloudKit.coupleID {
            Task.detached {
                try? await Firestore.firestore()
                    .collection("couples").document(cid)
                    .collection("photoBlobs").document(filename).delete()
            }
        }

        guard let idx = blocksByTrip[block.tripID]?.firstIndex(where: { $0.id == block.id }) else { return }
        let existing = blocksByTrip[block.tripID]?[idx].text ?? ""
        var filenames = (try? JSONDecoder().decode([String].self, from: Data(existing.utf8))) ?? []
        filenames.removeAll { $0 == filename }
        let newText = (try? String(data: JSONEncoder().encode(filenames), encoding: .utf8)) ?? ""
        blocksByTrip[block.tripID]?[idx].text = newText
        if let updated = blocksByTrip[block.tripID]?[idx] {
            Task { _ = try? await cloudKit.saveBlock(updated) }
        }
    }

    func migratePhotosToCloudIfNeeded() async {
        let key = "photos_migrated_v2_firestore"
        if UserDefaults.standard.bool(forKey: key) { return }
        guard let cid = cloudKit.coupleID else { return }
        let dir = photosDirectory()
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            UserDefaults.standard.set(true, forKey: key)
            return
        }
        let db = Firestore.firestore()
        for name in names {
            let url = dir.appendingPathComponent(name)
            guard let raw = try? Data(contentsOf: url),
                  let img = UIImage(data: raw),
                  let compressed = compressForFirestore(img) else { continue }
            let base64 = compressed.base64EncodedString()
            _ = try? await db.collection("couples").document(cid)
                .collection("photoBlobs").document(name)
                .setData(["data": base64])
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    // Scale to max 1024px and compress until under Firestore's 1 MiB doc cap (with base64 inflation).
    private func compressForFirestore(_ image: UIImage) -> Data? {
        let maxDim: CGFloat = 1024
        let scale: CGFloat = (image.size.width > maxDim || image.size.height > maxDim)
            ? maxDim / max(image.size.width, image.size.height)
            : 1.0
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        var quality: CGFloat = 0.6
        while quality > 0.1 {
            if let d = resized.jpegData(compressionQuality: quality), d.count < 700_000 {
                return d
            }
            quality -= 0.1
        }
        return resized.jpegData(compressionQuality: 0.1)
    }

    func addBlock(title: String, type: TripBlockType, to trip: OursSubcategory) async {
        let blockCount = blocksByTrip[trip.id]?.count ?? 0
        let childCount = (subcategoriesByCategory[trip.categoryID] ?? [])
            .filter { $0.parentSubcategoryID == trip.id }.count
        let itemCount = itemsBySubcategory[trip.id]?.count ?? 0
        let order = blockCount + childCount + itemCount
        let block = TripBlock(tripID: trip.id, title: title, type: type, order: order)
        blocksByTrip[trip.id, default: []].append(block)
        if type == .checklist { checkItemsByBlock[block.id] = [] }
        _ = try? await cloudKit.saveBlock(block)
    }

    func deleteBlock(_ block: TripBlock) async {
        let checkItems = LocalStore.shared.tripCheckItems.filter { $0.blockID == block.id }
        let label = block.title.isEmpty ? "Block borttaget" : "\(block.title) borttagen"
        let snapshot = DeletedSnapshot(label: label,
                                       subcategories: [], items: [],
                                       blocks: [block], checkItems: checkItems,
                                       photoFiles: capturePhotoFiles(for: [block]))
        deletePhotoBlobs(in: block)
        try? await cloudKit.deleteBlock(block)
        blocksByTrip[block.tripID]?.removeAll { $0.id == block.id }
        checkItemsByBlock.removeValue(forKey: block.id)
        offerUndo(snapshot)
    }

    private func deletePhotoBlobs(in block: TripBlock) {
        guard block.type == .photos,
              let data = block.text.data(using: .utf8),
              let filenames = try? JSONDecoder().decode([String].self, from: data),
              !filenames.isEmpty
        else { return }
        let dir = photosDirectory()
        let cid = cloudKit.coupleID
        for filename in filenames {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(filename))
            if let cid {
                Task.detached {
                    try? await Firestore.firestore()
                        .collection("couples").document(cid)
                        .collection("photoBlobs").document(filename).delete()
                }
            }
        }
    }

    func moveBlock(tripID: UUID, fromOffsets: IndexSet, toOffset: Int) {
        guard var blocks = blocksByTrip[tripID] else { return }
        blocks.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for i in blocks.indices { blocks[i].order = i }
        blocksByTrip[tripID] = blocks
        Task { for b in blocks { _ = try? await cloudKit.saveBlock(b) } }
    }

    func updateBlockTitle(_ title: String, for block: TripBlock) {
        guard let idx = blocksByTrip[block.tripID]?.firstIndex(where: { $0.id == block.id }) else { return }
        blocksByTrip[block.tripID]?[idx].title = title
        guard let updated = blocksByTrip[block.tripID]?[idx] else { return }
        blockSaveTasks[block.id]?.cancel()
        blockSaveTasks[block.id] = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            _ = try? await cloudKit.saveBlock(updated)
        }
    }

    func updateBlockText(_ text: String, for block: TripBlock) {
        guard let idx = blocksByTrip[block.tripID]?.firstIndex(where: { $0.id == block.id }) else { return }
        blocksByTrip[block.tripID]?[idx].text = text
        guard let updated = blocksByTrip[block.tripID]?[idx] else { return }
        blockSaveTasks[block.id]?.cancel()
        blockSaveTasks[block.id] = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            _ = try? await cloudKit.saveBlock(updated)
        }
    }

    // MARK: - Trip Check Item CRUD

    func addCheckItem(title: String, to block: TripBlock) async {
        let order = checkItemsByBlock[block.id]?.count ?? 0
        var item = TripCheckItem(blockID: block.id, title: title, order: order)
        item = (try? await cloudKit.saveCheckItem(item)) ?? item
        checkItemsByBlock[block.id, default: []].append(item)
    }

    func toggleCheckItem(_ item: TripCheckItem) async {
        var updated = item
        updated.isChecked.toggle()
        updated = (try? await cloudKit.saveCheckItem(updated)) ?? updated
        if let idx = checkItemsByBlock[item.blockID]?.firstIndex(where: { $0.id == item.id }) {
            checkItemsByBlock[item.blockID]?[idx] = updated
        }
    }

    func deleteCheckItem(_ item: TripCheckItem) async {
        try? await cloudKit.deleteCheckItem(item)
        checkItemsByBlock[item.blockID]?.removeAll { $0.id == item.id }
        offerUndo(DeletedSnapshot(label: "\(item.title) borttagen",
                                  subcategories: [], items: [],
                                  blocks: [], checkItems: [item], photoFiles: []))
    }

    private var checkItemSaveTasks: [UUID: Task<Void, Never>] = [:]

    func updateCheckItemTitle(_ title: String, for item: TripCheckItem) {
        guard let idx = checkItemsByBlock[item.blockID]?.firstIndex(where: { $0.id == item.id }) else { return }
        checkItemsByBlock[item.blockID]?[idx].title = title
        guard let updated = checkItemsByBlock[item.blockID]?[idx] else { return }
        checkItemSaveTasks[item.id]?.cancel()
        checkItemSaveTasks[item.id] = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            _ = try? await cloudKit.saveCheckItem(updated)
        }
    }

    // MARK: - Recipe import

    @discardableResult
    func createRecipeFromDraft(_ draft: RecipeDraft, in category: OursCategory,
                               parent: OursSubcategory? = nil) async -> OursSubcategory? {
        let order = (subcategoriesByCategory[category.id] ?? [])
            .filter { $0.parentSubcategoryID == parent?.id }.count
        let icon = draft.iconHint ?? category.suggestedIcons.first ?? "fork.knife"
        let sub = OursSubcategory(
            name: draft.name, iconName: icon, order: order,
            categoryID: category.id, note: "",
            parentSubcategoryID: parent?.id
        )
        subcategoriesByCategory[category.id, default: []].append(sub)
        _ = try? await cloudKit.saveSubcategory(sub)

        // Pre-create blocks so loadBlocks doesn't run the empty-recipe migration.
        var instrBlock = TripBlock(tripID: sub.id, title: "Instruktioner",
                                   type: .note, order: 0, text: draft.instructions)
        instrBlock = (try? await cloudKit.saveBlock(instrBlock)) ?? instrBlock

        var ingrBlock = TripBlock(tripID: sub.id, title: "Ingredienser",
                                  type: .checklist, order: 1)
        ingrBlock = (try? await cloudKit.saveBlock(ingrBlock)) ?? ingrBlock

        var checkItems: [TripCheckItem] = []
        for (i, line) in draft.ingredients.enumerated() {
            var ci = TripCheckItem(blockID: ingrBlock.id, title: line, order: i)
            ci = (try? await cloudKit.saveCheckItem(ci)) ?? ci
            checkItems.append(ci)
        }

        blocksByTrip[sub.id] = [instrBlock, ingrBlock]
        checkItemsByBlock[ingrBlock.id] = checkItems
        return sub
    }

    // MARK: - Recipe seeding

    private struct RecipeSeed {
        let name: String
        let icon: String
        let portions: Int
        let instructions: String
        let ingredients: [String]
    }

    func migrateBudgetIncomeIfNeeded() async {
        let key = "budget_income_migrated_v1"
        if UserDefaults.standard.bool(forKey: key) { return }

        let ekonomiID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        guard let cat = categories.first(where: { $0.id == ekonomiID }) else { return }
        if subcategoriesByCategory[ekonomiID] == nil { await loadSubcategories(for: cat) }

        guard let myName = currentProfile?.name, !myName.isEmpty,
              let mySection = (subcategoriesByCategory[ekonomiID] ?? [])
                  .first(where: { $0.name == myName })
        else { return }

        if blocksByTrip[mySection.id] == nil { await loadBlocks(for: mySection) }

        guard let budgetIdx = blocksByTrip[mySection.id]?
            .firstIndex(where: { $0.type == .budget })
        else {
            // No budget yet — will be created with income via seedBudgetBlock on first open
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        let existingText = blocksByTrip[mySection.id]?[budgetIdx].text ?? ""
        if existingText.contains("## Inkomst") {
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        let newText = "## Inkomst\nLön (efter skatt): 50000\n" + existingText
        blocksByTrip[mySection.id]?[budgetIdx].text = newText
        if let updated = blocksByTrip[mySection.id]?[budgetIdx] {
            _ = try? await cloudKit.saveBlock(updated)
        }

        UserDefaults.standard.set(true, forKey: key)
    }

    func seedRecipesIfNeeded() async {
        let key = "recipes_seeded_v1"
        if UserDefaults.standard.bool(forKey: key) { return }

        let receptID = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
        guard let receptCategory = categories.first(where: { $0.id == receptID }) else { return }

        if subcategoriesByCategory[receptID] == nil {
            await loadSubcategories(for: receptCategory)
        }

        let existingNames = Set((subcategoriesByCategory[receptID] ?? [])
            .map { $0.name.lowercased() })

        for seed in Self.recipeSeeds {
            guard !existingNames.contains(seed.name.lowercased()) else { continue }

            let order = (subcategoriesByCategory[receptID] ?? []).count
            let sub = OursSubcategory(
                name: seed.name,
                iconName: seed.icon,
                order: order,
                categoryID: receptID,
                note: "",
                portions: seed.portions
            )
            subcategoriesByCategory[receptID, default: []].append(sub)
            _ = try? await cloudKit.saveSubcategory(sub)

            var instrBlock = TripBlock(tripID: sub.id, title: "Instruktioner",
                                       type: .note, order: 0, text: seed.instructions)
            instrBlock = (try? await cloudKit.saveBlock(instrBlock)) ?? instrBlock

            var ingrBlock = TripBlock(tripID: sub.id, title: "Ingredienser",
                                      type: .checklist, order: 1)
            ingrBlock = (try? await cloudKit.saveBlock(ingrBlock)) ?? ingrBlock

            var checkItems: [TripCheckItem] = []
            for (i, line) in seed.ingredients.enumerated() {
                var ci = TripCheckItem(blockID: ingrBlock.id, title: line, order: i)
                ci = (try? await cloudKit.saveCheckItem(ci)) ?? ci
                checkItems.append(ci)
            }
            blocksByTrip[sub.id] = [instrBlock, ingrBlock]
            checkItemsByBlock[ingrBlock.id] = checkItems
        }

        UserDefaults.standard.set(true, forKey: key)
    }

    private static let recipeSeeds: [RecipeSeed] = [
        RecipeSeed(
            name: "Potatisterrin",
            icon: "carrot.fill",
            portions: 4,
            instructions: """
            1. Smält smör med vitlök och kryddor.
            2. Blanda finskivad potatis med smörblandningen.
            3. Lägg i ugnsform, strö lite potatismjöl mellan varje lager.
            4. Pressa, täck med en annan form.
            5. Ugn 140°C i 2 timmar.
            6. Pressa igen, kyl över natten.
            7. Skär i bitar. Stek i olivolja (säkrast) eller djupfritera en i taget, stackad (inte på sidan).
            """,
            ingredients: [
                "Potatis (finskivad)",
                "Smör",
                "Vitlök",
                "Kryddor",
                "Potatismjöl",
                "Olivolja (till stekning)"
            ]
        ),
        RecipeSeed(
            name: "Köttfärssås",
            icon: "fork.knife",
            portions: 4,
            instructions: """
            1. Hacka och stek lök och vitlök.
            2. Bryn nötfärsen.
            3. Tillsätt finkrossade tomater och kalvfond.
            4. Smaksätt med crème fraîche, sesamolja, hoisin, worcestershire, soja, oyster sauce och kryddor.
            5. Låt puttra tills såsen tjocknar.
            """,
            ingredients: [
                "Nötfärs",
                "Gul lök",
                "Vitlök",
                "Finkrossade tomater",
                "Crème fraîche (paprika)",
                "Kalvfond",
                "Sesamolja",
                "Hoisinsås",
                "Worcestershiresås",
                "Soja",
                "Thick oyster sauce",
                "Kryddor"
            ]
        ),
        RecipeSeed(
            name: "Pepparsås",
            icon: "flame.fill",
            portions: 4,
            instructions: """
            1. Använd samma panna som köttet stektes i, ös och ta bort lite smör.
            2. Tillsätt grädde, crème fraîche och kalvfond.
            3. Smaksätt med 5 spices, soja, whisky, peppar och dijonsenap.
            4. Låt reducera lätt.
            """,
            ingredients: [
                "Grädde",
                "Crème fraîche",
                "Kalvfond",
                "5 spices",
                "Soja",
                "Whisky",
                "Peppar",
                "Dijonsenap",
                "Smör (från köttpannan)"
            ]
        ),
        RecipeSeed(
            name: "Tryffelpasta",
            icon: "leaf.fill",
            portions: 4,
            instructions: """
            1. Stek 4–6 schalottenlök i smör tills mjuka.
            2. Tillsätt 4–5 dl grädde, koka upp.
            3. Rör i 2 msk Zeta svamp/tryffelcreme.
            4. Koka 2 pkt tryffel/parmesan-tortellini parallellt.
            5. Stek oxfilé i olivolja separat.
            6. Servera tortellinin med såsen, skivad oxfilé, riven parmesan och persilja.
            """,
            ingredients: [
                "2 pkt tryffel/parmesan-tortellini",
                "4–6 schalottenlökar",
                "4–5 dl grädde",
                "2 msk Zeta svamp/tryffelcreme",
                "Smör",
                "Olivolja",
                "Oxfilé",
                "Parmesanost",
                "Persilja"
            ]
        ),
        RecipeSeed(
            name: "Pesto pasta",
            icon: "leaf.fill",
            portions: 4,
            instructions: """
            1. Koka linguini.
            2. Häll av vattnet 3 min innan pastan är färdig — lämna lite kokvatten i botten.
            3. Häll i pesto, rör runt.
            4. Lägg burrata på toppen och servera.
            """,
            ingredients: [
                "500 g linguini",
                "1 burk pesto (~250 g)",
                "1 burrata"
            ]
        ),
        RecipeSeed(
            name: "Martins jordnötssås",
            icon: "hare.fill",
            portions: 4,
            instructions: """
            1. Hacka lök, vitlök och chili så smått som möjligt.
            2. Stek i olja eller smör tills mjukt.
            3. Tillsätt 2 tsk curry.
            4. Tillsätt 1–2 dl jordnötssmör, rör runt rejält.
            5. Skaka kokosmjölken, häll i.
            6. Smaksätt fritt med soja, honung/råsocker, sweet chili, salt och hot sauce — känn dig fram.
            """,
            ingredients: [
                "1 stor gul lök",
                "2–3 vitlöksklyftor",
                "1 chili (valfritt)",
                "Olja eller smör (till stekning)",
                "2 tsk curry",
                "1–2 dl jordnötssmör",
                "1 burk kokosmjölk",
                "Soja (efter smak)",
                "Honung eller råsocker (efter smak)",
                "Sweet chili (efter smak)",
                "Salt (efter smak)",
                "Hot sauce (efter smak)"
            ]
        )
    ]
}
