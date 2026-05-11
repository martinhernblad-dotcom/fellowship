import FirebaseFirestore
import Foundation
import UIKit

// MARK: - CloudKitService (backed by Firestore)
// Named CloudKitService to keep the rest of the app unchanged.

@MainActor
final class CloudKitService {

    private let store = LocalStore.shared
    private var db: Firestore { Firestore.firestore() }
    private var listeners: [ListenerRegistration] = []

    var onDataChanged: (@MainActor () -> Void)?

    var coupleID: String? {
        get { UserDefaults.standard.string(forKey: "fellowship_couple_id") }
        set { UserDefaults.standard.set(newValue, forKey: "fellowship_couple_id") }
    }

    // MARK: - Account (no-op for Firebase)
    func accountStatus() async throws -> Int { 1 }

    // MARK: - Pairing

    func createCoupleCode() async throws -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let code = String((0..<6).map { _ in chars.randomElement()! })
        try await db.collection("pairings").document(code).setData([
            "createdBy": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "createdAt": FieldValue.serverTimestamp()
        ])
        coupleID = code
        await pushAll()
        return code
    }

    func joinCouple(code: String) async throws -> Bool {
        let key = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let doc = try await db.collection("pairings").document(key).getDocument()
        guard doc.exists else { return false }
        coupleID = key
        return true
    }

    // MARK: - Push all local data to Firestore

    func pushAll() async {
        guard let cid = coupleID else { return }
        let batch = db.batch()
        for sub  in store.subcategories  { batch.setData(sub.toFirestore(),  forDocument: firestoreRef("subcategories",  id: sub.id.uuidString,  coupleID: cid)) }
        for item in store.items          { batch.setData(item.toFirestore(), forDocument: firestoreRef("items",          id: item.id.uuidString, coupleID: cid)) }
        for blk  in store.tripBlocks     { batch.setData(blk.toFirestore(),  forDocument: firestoreRef("tripBlocks",     id: blk.id.uuidString,  coupleID: cid)) }
        for ci   in store.tripCheckItems { batch.setData(ci.toFirestore(),   forDocument: firestoreRef("tripCheckItems", id: ci.id.uuidString,   coupleID: cid)) }
        for pr   in store.profiles       { batch.setData(pr.toFirestore(),   forDocument: firestoreRef("profiles",       id: pr.deviceID,        coupleID: cid)) }
        try? await batch.commit()
    }

    // MARK: - Full sync (pull from Firestore, merge into local)

    func syncAll() async throws {
        guard let cid = coupleID else { return }
        async let scs  = firestoreFetchAll("subcategories",  coupleID: cid)
        async let its  = firestoreFetchAll("items",          coupleID: cid)
        async let bls  = firestoreFetchAll("tripBlocks",     coupleID: cid)
        async let cis  = firestoreFetchAll("tripCheckItems", coupleID: cid)
        async let prs  = firestoreFetchAll("profiles",       coupleID: cid)
        async let dels = firestoreFetchAll("deletions",      coupleID: cid)
        let (scDocs, itDocs, blDocs, ciDocs, prDocs, delDocs) = try await (scs, its, bls, cis, prs, dels)
        // Apply deletions first so re-added items aren't immediately removed
        delDocs.forEach { d in
            if let col = d["collection"] as? String, let id = d["id"] as? String {
                store.applyDeletion(collection: col, id: id)
            }
        }
        scDocs.compactMap(OursSubcategory.init(fs:)).forEach { store.merge($0) }
        itDocs.compactMap(ListItem.init(fs:)).forEach        { store.merge($0) }
        blDocs.compactMap(TripBlock.init(fs:)).forEach       { store.merge($0) }
        ciDocs.compactMap(TripCheckItem.init(fs:)).forEach   { store.merge($0) }
        prDocs.compactMap(UserProfile.init(fs:)).forEach     { store.merge($0) }
        // Profiles aren't tombstoned (no in-app delete API), so reconcile:
        // remove any local profile whose deviceID isn't present in the fetched
        // set. Keying by deviceID matters because old + new docs for the same
        // person may share a UUID (UserDefaults carry-over across reinstalls)
        // but differ in deviceID — and Firestore keys profile docs by deviceID.
        let validDeviceIDs = Set(prDocs.compactMap { $0["deviceID"] as? String })
        store.profiles.removeAll { !validDeviceIDs.contains($0.deviceID) }
        store.save()
    }

    private func firestoreFetchAll(_ collection: String, coupleID: String) async throws -> [[String: Any]] {
        let snap = try await db.collection("couples").document(coupleID).collection(collection).getDocuments()
        return snap.documents.map { $0.data() }
    }

    private func firestoreRef(_ collection: String, id: String, coupleID: String) -> DocumentReference {
        db.collection("couples").document(coupleID).collection(collection).document(id)
    }

    func setupSubscriptions() async {
        guard let cid = coupleID else { return }
        guard listeners.isEmpty else { return }

        let collections = ["subcategories", "items", "tripBlocks", "tripCheckItems", "profiles", "deletions"]
        for collection in collections {
            let listener = db.collection("couples").document(cid).collection(collection)
                .addSnapshotListener { [weak self] snap, _ in
                    guard let self, let snap else { return }
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.processSnapshot(snap, collection: collection)
                        self.onDataChanged?()
                    }
                }
            listeners.append(listener)
        }
    }

    private func processSnapshot(_ snap: QuerySnapshot, collection: String) {
        var changed = false
        for change in snap.documentChanges {
            let data = change.document.data()
            switch change.type {
            case .added, .modified:
                applyMerge(data: data, collection: collection)
                changed = true
            case .removed:
                // For most collections the doc ID is the entity UUID; for
                // profiles it's the deviceID. applyDeletion handles both.
                let id = change.document.documentID
                store.applyDeletion(collection: collection, id: id)
                changed = true
            }
        }
        if changed { store.save() }
    }

    private func applyMerge(data: [String: Any], collection: String) {
        switch collection {
        case "subcategories":
            if let v = OursSubcategory(fs: data) { store.merge(v) }
        case "items":
            if let v = ListItem(fs: data) { store.merge(v) }
        case "tripBlocks":
            if let v = TripBlock(fs: data) { store.merge(v) }
        case "tripCheckItems":
            if let v = TripCheckItem(fs: data) { store.merge(v) }
        case "profiles":
            if let v = UserProfile(fs: data) { store.merge(v) }
        case "deletions":
            if let col = data["collection"] as? String, let id = data["id"] as? String {
                store.applyDeletion(collection: col, id: id)
            }
        default: break
        }
    }

    // MARK: - Categories

    func fetchCategories() async throws -> [OursCategory] { store.categories }

    func seedCategoriesIfNeeded() async throws {
        if store.categories.isEmpty {
            store.categories = OursCategory.seed
            store.save()
        } else {
            var changed = false
            for i in store.categories.indices {
                if store.categories[i].iconName == "fork.knife",
                   store.categories[i].id == UUID(uuidString: "00000000-0000-0000-0000-000000000006")! {
                    store.categories[i].iconName = "pot.fill"
                    changed = true
                }
            }
            if changed { store.save() }
        }
    }

    func saveCategory(_ category: OursCategory) async throws -> OursCategory {
        store.merge(category)
        store.save()
        return category
    }

    // MARK: - Subcategories

    func fetchSubcategories(for categoryID: UUID) async throws -> [OursSubcategory] {
        store.subcategories.filter { $0.categoryID == categoryID }.sorted { $0.order < $1.order }
    }

    func saveSubcategory(_ sub: OursSubcategory) async throws -> OursSubcategory {
        store.merge(sub)
        store.save()
        fsPush("subcategories", id: sub.id.uuidString, data: sub.toFirestore())
        return sub
    }

    func deleteSubcategory(_ sub: OursSubcategory) async throws {
        let descendantIDs = store.descendantSubcategoryIDs(of: sub.id)
        let allIDs = Set([sub.id] + descendantIDs)
        let blockIDs = store.tripBlocks.filter { allIDs.contains($0.tripID) }.map(\.id)
        store.subcategories.removeAll   { allIDs.contains($0.id) }
        store.items.removeAll           { allIDs.contains($0.subcategoryID) }
        store.tripBlocks.removeAll      { allIDs.contains($0.tripID) }
        store.tripCheckItems.removeAll  { blockIDs.contains($0.blockID) }
        store.save()
        for id in allIDs {
            fsDelete("subcategories", id: id.uuidString)
            fsTombstone("subcategories", id: id.uuidString)
        }
    }

    // MARK: - Items

    func fetchItems(for subcategoryID: UUID) async throws -> [ListItem] {
        store.items.filter { $0.subcategoryID == subcategoryID }.sorted { $0.order < $1.order }
    }

    func saveItem(_ item: ListItem) async throws -> ListItem {
        store.merge(item)
        store.save()
        fsPush("items", id: item.id.uuidString, data: item.toFirestore())
        return item
    }

    func deleteItem(_ item: ListItem) async throws {
        store.items.removeAll { $0.id == item.id }
        store.save()
        fsDelete("items", id: item.id.uuidString)
        fsTombstone("items", id: item.id.uuidString)
    }

    // MARK: - Trip Blocks

    func fetchBlocks(for tripID: UUID) async throws -> [TripBlock] {
        store.tripBlocks.filter { $0.tripID == tripID }.sorted { $0.order < $1.order }
    }

    func saveBlock(_ block: TripBlock) async throws -> TripBlock {
        store.merge(block)
        store.save()
        fsPush("tripBlocks", id: block.id.uuidString, data: block.toFirestore())
        return block
    }

    func deleteBlock(_ block: TripBlock) async throws {
        store.tripBlocks.removeAll     { $0.id == block.id }
        store.tripCheckItems.removeAll { $0.blockID == block.id }
        store.save()
        fsDelete("tripBlocks", id: block.id.uuidString)
        fsTombstone("tripBlocks", id: block.id.uuidString)
    }

    // MARK: - Trip Check Items

    func fetchCheckItems(for blockID: UUID) async throws -> [TripCheckItem] {
        store.tripCheckItems.filter { $0.blockID == blockID }.sorted { $0.order < $1.order }
    }

    func saveCheckItem(_ item: TripCheckItem) async throws -> TripCheckItem {
        store.merge(item)
        store.save()
        fsPush("tripCheckItems", id: item.id.uuidString, data: item.toFirestore())
        return item
    }

    func deleteCheckItem(_ item: TripCheckItem) async throws {
        store.tripCheckItems.removeAll { $0.id == item.id }
        store.save()
        fsDelete("tripCheckItems", id: item.id.uuidString)
        fsTombstone("tripCheckItems", id: item.id.uuidString)
    }

    // MARK: - Profiles

    func fetchProfiles() async throws -> [UserProfile] { store.profiles }

    func saveProfile(_ profile: UserProfile) async throws -> UserProfile {
        store.merge(profile)
        store.save()
        fsPush("profiles", id: profile.deviceID, data: profile.toFirestore())
        return profile
    }

    // MARK: - Firestore helpers

    private func fsPush(_ collection: String, id: String, data: [String: Any]) {
        guard let cid = coupleID else { return }
        Task { try? await firestoreRef(collection, id: id, coupleID: cid).setData(data) }
    }

    private func fsDelete(_ collection: String, id: String) {
        guard let cid = coupleID else { return }
        Task { try? await firestoreRef(collection, id: id, coupleID: cid).delete() }
    }

    private func fsTombstone(_ collection: String, id: String) {
        guard let cid = coupleID else { return }
        let docID = "\(collection)_\(id)"
        let data: [String: Any] = ["collection": collection, "id": id,
                                   "deletedAt": FieldValue.serverTimestamp()]
        Task {
            try? await db.collection("couples").document(cid)
                .collection("deletions").document(docID).setData(data)
        }
    }
}

// MARK: - Firestore mapping

private extension OursSubcategory {
    func toFirestore() -> [String: Any] {
        var d: [String: Any] = [
            "id": id.uuidString, "categoryID": categoryID.uuidString,
            "name": name, "iconName": iconName, "order": order, "note": note,
            "portions": portions
        ]
        if let p = parentSubcategoryID { d["parentSubcategoryID"] = p.uuidString }
        return d
    }
    init?(fs d: [String: Any]) {
        guard let idStr  = d["id"]         as? String, let id     = UUID(uuidString: idStr),
              let catStr = d["categoryID"] as? String, let catID  = UUID(uuidString: catStr)
        else { return nil }
        self.id = id; self.categoryID = catID
        self.name     = d["name"]     as? String ?? ""
        self.iconName = d["iconName"] as? String ?? "folder.fill"
        self.order    = d["order"]    as? Int    ?? 0
        self.note     = d["note"]     as? String ?? ""
        self.portions = d["portions"] as? Int    ?? 1
        if let pStr = d["parentSubcategoryID"] as? String, let pID = UUID(uuidString: pStr) {
            self.parentSubcategoryID = pID
        } else {
            self.parentSubcategoryID = nil
        }
    }
}

private extension ListItem {
    func toFirestore() -> [String: Any] {[
        "id": id.uuidString, "subcategoryID": subcategoryID.uuidString,
        "title": title, "notes": notes, "url": url,
        "isCompleted": isCompleted, "order": order,
        "createdAt": createdAt.timeIntervalSince1970
    ]}
    init?(fs d: [String: Any]) {
        guard let idStr  = d["id"]            as? String, let id    = UUID(uuidString: idStr),
              let subStr = d["subcategoryID"] as? String, let subID = UUID(uuidString: subStr)
        else { return nil }
        self.id = id; self.subcategoryID = subID
        self.title       = d["title"]       as? String ?? ""
        self.notes       = d["notes"]       as? String ?? ""
        self.url         = d["url"]         as? String ?? ""
        self.isCompleted = d["isCompleted"] as? Bool   ?? false
        self.order       = d["order"]       as? Int    ?? 0
        self.createdAt   = Date(timeIntervalSince1970: d["createdAt"] as? Double ?? 0)
    }
}

private extension TripBlock {
    func toFirestore() -> [String: Any] {[
        "id": id.uuidString, "tripID": tripID.uuidString,
        "title": title, "type": type.rawValue, "order": order, "text": text
    ]}
    init?(fs d: [String: Any]) {
        guard let idStr   = d["id"]     as? String, let id     = UUID(uuidString: idStr),
              let tripStr = d["tripID"] as? String, let tripID = UUID(uuidString: tripStr),
              let typeStr = d["type"]   as? String, let type   = TripBlockType(rawValue: typeStr)
        else { return nil }
        self.id = id; self.tripID = tripID; self.type = type
        self.title = d["title"] as? String ?? ""
        self.order = d["order"] as? Int    ?? 0
        self.text  = d["text"]  as? String ?? ""
    }
}

private extension TripCheckItem {
    func toFirestore() -> [String: Any] {[
        "id": id.uuidString, "blockID": blockID.uuidString,
        "title": title, "isChecked": isChecked, "order": order
    ]}
    init?(fs d: [String: Any]) {
        guard let idStr  = d["id"]      as? String, let id      = UUID(uuidString: idStr),
              let blkStr = d["blockID"] as? String, let blockID = UUID(uuidString: blkStr)
        else { return nil }
        self.id = id; self.blockID = blockID
        self.title     = d["title"]     as? String ?? ""
        self.isChecked = d["isChecked"] as? Bool   ?? false
        self.order     = d["order"]     as? Int    ?? 0
    }
}

private extension UserProfile {
    func toFirestore() -> [String: Any] {[
        "id": id.uuidString, "deviceID": deviceID, "name": name, "emoji": emoji
    ]}
    init?(fs d: [String: Any]) {
        guard let idStr  = d["id"]       as? String, let id    = UUID(uuidString: idStr),
              let devID  = d["deviceID"] as? String
        else { return nil }
        self.id = id; self.deviceID = devID
        self.name  = d["name"]  as? String ?? ""
        self.emoji = d["emoji"] as? String ?? "🙂"
    }
}

// MARK: - LocalStore

final class LocalStore {
    static let shared = LocalStore()

    var categories:     [OursCategory]    = []
    var subcategories:  [OursSubcategory] = []
    var items:          [ListItem]        = []
    var profiles:       [UserProfile]     = []
    var tripBlocks:     [TripBlock]       = []
    var tripCheckItems: [TripCheckItem]   = []

    private let url: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let file = dir.appendingPathComponent("fellowship_store_v2.json")
        try? (file as NSURL).setResourceValue(false, forKey: .isExcludedFromBackupKey)
        return file
    }()

    private init() { load() }

    func merge(_ cat: OursCategory) {
        if let i = categories.firstIndex(where: { $0.id == cat.id }) { categories[i] = cat }
        else { categories.append(cat) }
    }
    func merge(_ sub: OursSubcategory) {
        if let i = subcategories.firstIndex(where: { $0.id == sub.id }) { subcategories[i] = sub }
        else { subcategories.append(sub) }
    }
    func merge(_ item: ListItem) {
        if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = item }
        else { items.append(item) }
    }
    func merge(_ block: TripBlock) {
        if let i = tripBlocks.firstIndex(where: { $0.id == block.id }) { tripBlocks[i] = block }
        else { tripBlocks.append(block) }
    }
    func merge(_ ci: TripCheckItem) {
        if let i = tripCheckItems.firstIndex(where: { $0.id == ci.id }) { tripCheckItems[i] = ci }
        else { tripCheckItems.append(ci) }
    }
    func merge(_ profile: UserProfile) {
        if let i = profiles.firstIndex(where: { $0.deviceID == profile.deviceID }) { profiles[i] = profile }
        else { profiles.append(profile) }
    }

    func descendantSubcategoryIDs(of parentID: UUID) -> [UUID] {
        var result: [UUID] = []
        var frontier: [UUID] = [parentID]
        while let current = frontier.popLast() {
            let kids = subcategories.filter { $0.parentSubcategoryID == current }.map(\.id)
            result.append(contentsOf: kids)
            frontier.append(contentsOf: kids)
        }
        return result
    }

    func applyDeletion(collection: String, id: String) {
        guard let uuid = UUID(uuidString: id) else { return }
        switch collection {
        case "subcategories":
            let descendantIDs = descendantSubcategoryIDs(of: uuid)
            let allIDs = Set([uuid] + descendantIDs)
            let blockIDs = tripBlocks.filter { allIDs.contains($0.tripID) }.map(\.id)
            let photoFilenames = collectPhotoFilenames(blockIDs: blockIDs)
            subcategories.removeAll  { allIDs.contains($0.id) }
            items.removeAll          { allIDs.contains($0.subcategoryID) }
            tripBlocks.removeAll     { allIDs.contains($0.tripID) }
            tripCheckItems.removeAll { blockIDs.contains($0.blockID) }
            deleteLocalPhotoFiles(photoFilenames)
        case "items":
            items.removeAll { $0.id == uuid }
        case "tripBlocks":
            let photoFilenames = collectPhotoFilenames(blockIDs: [uuid])
            tripCheckItems.removeAll { $0.blockID == uuid }
            tripBlocks.removeAll     { $0.id == uuid }
            deleteLocalPhotoFiles(photoFilenames)
        case "tripCheckItems":
            tripCheckItems.removeAll { $0.id == uuid }
        case "profiles":
            // For profiles the Firestore doc ID is the deviceID, not the entity UUID.
            profiles.removeAll { $0.deviceID == id }
        default: break
        }
    }

    private func collectPhotoFilenames(blockIDs: [UUID]) -> [String] {
        let ids = Set(blockIDs)
        return tripBlocks
            .filter { ids.contains($0.id) && $0.type == .photos }
            .flatMap { block -> [String] in
                guard let data = block.text.data(using: .utf8),
                      let names = try? JSONDecoder().decode([String].self, from: data)
                else { return [] }
                return names
            }
    }

    private func deleteLocalPhotoFiles(_ filenames: [String]) {
        guard !filenames.isEmpty else { return }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("recipe_photos", isDirectory: true)
        for filename in filenames {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(filename))
        }
    }

    func save() {
        let payload = StorePayload(categories: categories, subcategories: subcategories,
                                   items: items, profiles: profiles,
                                   tripBlocks: tripBlocks, tripCheckItems: tripCheckItems)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(StorePayload.self, from: data)
        else { return }
        categories     = payload.categories
        subcategories  = payload.subcategories
        items          = payload.items
        profiles       = payload.profiles
        tripBlocks     = payload.tripBlocks
        tripCheckItems = payload.tripCheckItems
    }
}

// MARK: - StorePayload

private struct StorePayload: Codable {
    var categories:     [OursCategory]
    var subcategories:  [OursSubcategory]
    var items:          [ListItem]
    var profiles:       [UserProfile]
    var tripBlocks:     [TripBlock]
    var tripCheckItems: [TripCheckItem]

    enum CodingKeys: String, CodingKey {
        case categories, subcategories, items, profiles, tripBlocks, tripCheckItems
    }

    init(categories: [OursCategory], subcategories: [OursSubcategory],
         items: [ListItem], profiles: [UserProfile],
         tripBlocks: [TripBlock], tripCheckItems: [TripCheckItem]) {
        self.categories = categories; self.subcategories = subcategories
        self.items = items; self.profiles = profiles
        self.tripBlocks = tripBlocks; self.tripCheckItems = tripCheckItems
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categories     = try c.decode([OursCategory].self,    forKey: .categories)
        subcategories  = try c.decode([OursSubcategory].self, forKey: .subcategories)
        items          = try c.decode([ListItem].self,         forKey: .items)
        profiles       = try c.decode([UserProfile].self,      forKey: .profiles)
        tripBlocks     = (try? c.decode([TripBlock].self,      forKey: .tripBlocks))     ?? []
        tripCheckItems = (try? c.decode([TripCheckItem].self,  forKey: .tripCheckItems)) ?? []
    }
}
