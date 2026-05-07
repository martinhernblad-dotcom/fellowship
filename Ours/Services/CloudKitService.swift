import Foundation

// Local JSON persistence — same interface as the CloudKit version.
// Swap this file for a CloudKit or Firebase implementation once you have
// a paid Apple Developer account or a Firebase project set up.

final class CloudKitService {

    private let store = LocalStore.shared

    // MARK: - Account (stub — always "available" locally)
    func accountStatus() async throws -> Int { 1 }

    // MARK: - Categories

    func fetchCategories() async throws -> [OursCategory] {
        store.categories
    }

    func seedCategoriesIfNeeded() async throws {
        if store.categories.isEmpty {
            store.categories = OursCategory.seed
            store.save()
        }
    }

    func saveCategory(_ category: OursCategory) async throws -> OursCategory {
        if let idx = store.categories.firstIndex(where: { $0.id == category.id }) {
            store.categories[idx] = category
        } else {
            store.categories.append(category)
        }
        store.save()
        return category
    }

    // MARK: - Subcategories

    func fetchSubcategories(for categoryID: UUID) async throws -> [OursSubcategory] {
        store.subcategories.filter { $0.categoryID == categoryID }
            .sorted { $0.order < $1.order }
    }

    func saveSubcategory(_ sub: OursSubcategory) async throws -> OursSubcategory {
        if let idx = store.subcategories.firstIndex(where: { $0.id == sub.id }) {
            store.subcategories[idx] = sub
        } else {
            store.subcategories.append(sub)
        }
        store.save()
        return sub
    }

    func deleteSubcategory(_ sub: OursSubcategory) async throws {
        store.subcategories.removeAll { $0.id == sub.id }
        store.items.removeAll { $0.subcategoryID == sub.id }
        // Also clean up trip blocks when a trip is deleted
        let blockIDs = store.tripBlocks.filter { $0.tripID == sub.id }.map(\.id)
        store.tripBlocks.removeAll { $0.tripID == sub.id }
        store.tripCheckItems.removeAll { blockIDs.contains($0.blockID) }
        store.save()
    }

    // MARK: - List Items

    func fetchItems(for subcategoryID: UUID) async throws -> [ListItem] {
        store.items.filter { $0.subcategoryID == subcategoryID }
            .sorted { $0.order < $1.order }
    }

    func saveItem(_ item: ListItem) async throws -> ListItem {
        if let idx = store.items.firstIndex(where: { $0.id == item.id }) {
            store.items[idx] = item
        } else {
            store.items.append(item)
        }
        store.save()
        return item
    }

    func deleteItem(_ item: ListItem) async throws {
        store.items.removeAll { $0.id == item.id }
        store.save()
    }

    // MARK: - Trip Blocks

    func fetchBlocks(for tripID: UUID) async throws -> [TripBlock] {
        store.tripBlocks.filter { $0.tripID == tripID }.sorted { $0.order < $1.order }
    }

    func saveBlock(_ block: TripBlock) async throws -> TripBlock {
        if let idx = store.tripBlocks.firstIndex(where: { $0.id == block.id }) {
            store.tripBlocks[idx] = block
        } else {
            store.tripBlocks.append(block)
        }
        store.save()
        return block
    }

    func deleteBlock(_ block: TripBlock) async throws {
        store.tripBlocks.removeAll { $0.id == block.id }
        store.tripCheckItems.removeAll { $0.blockID == block.id }
        store.save()
    }

    // MARK: - Trip Check Items

    func fetchCheckItems(for blockID: UUID) async throws -> [TripCheckItem] {
        store.tripCheckItems.filter { $0.blockID == blockID }.sorted { $0.order < $1.order }
    }

    func saveCheckItem(_ item: TripCheckItem) async throws -> TripCheckItem {
        if let idx = store.tripCheckItems.firstIndex(where: { $0.id == item.id }) {
            store.tripCheckItems[idx] = item
        } else {
            store.tripCheckItems.append(item)
        }
        store.save()
        return item
    }

    func deleteCheckItem(_ item: TripCheckItem) async throws {
        store.tripCheckItems.removeAll { $0.id == item.id }
        store.save()
    }

    // MARK: - Profiles

    func fetchProfiles() async throws -> [UserProfile] {
        store.profiles
    }

    func saveProfile(_ profile: UserProfile) async throws -> UserProfile {
        if let idx = store.profiles.firstIndex(where: { $0.deviceID == profile.deviceID }) {
            store.profiles[idx] = profile
        } else {
            store.profiles.append(profile)
        }
        store.save()
        return profile
    }

    // MARK: - Sync (no-op locally)
    func setupSubscriptions() async {}
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
        return dir.appendingPathComponent("fellowship_store_v2.json")
    }()

    private init() { load() }

    func save() {
        let payload = StorePayload(categories: categories, subcategories: subcategories,
                                   items: items, profiles: profiles,
                                   tripBlocks: tripBlocks, tripCheckItems: tripCheckItems)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: url)
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
