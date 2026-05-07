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

    let cloudKit = CloudKitService()

    private var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
    }

    var isProfileSetup: Bool { currentProfile != nil }

    var partnerProfile: UserProfile? {
        profiles.first { $0.deviceID != deviceID }
    }

    init() { restoreLocalProfile() }

    // MARK: - Profile

    private func restoreLocalProfile() {
        guard let name  = UserDefaults.standard.string(forKey: "profile_name"),
              let emoji = UserDefaults.standard.string(forKey: "profile_emoji")
        else { return }
        let idStr = UserDefaults.standard.string(forKey: "profile_id") ?? UUID().uuidString
        let id    = UUID(uuidString: idStr) ?? UUID()
        currentProfile = UserProfile(id: id, name: name, emoji: emoji, deviceID: deviceID)
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

    func setupSync() async {
        await cloudKit.setupSubscriptions()
    }

    // MARK: - Load

    func loadAll() async {
        try? await cloudKit.seedCategoriesIfNeeded()
        categories = (try? await cloudKit.fetchCategories()) ?? OursCategory.seed
        profiles   = (try? await cloudKit.fetchProfiles())   ?? []
    }

    func loadSubcategories(for category: OursCategory) async {
        subcategoriesByCategory[category.id] =
            (try? await cloudKit.fetchSubcategories(for: category.id)) ?? []
    }

    func loadItems(for subcategory: OursSubcategory) async {
        itemsBySubcategory[subcategory.id] =
            (try? await cloudKit.fetchItems(for: subcategory.id)) ?? []
    }

    func refreshAll() async {
        categories = (try? await cloudKit.fetchCategories()) ?? categories
        profiles   = (try? await cloudKit.fetchProfiles())   ?? profiles
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
    }

    // MARK: - Subcategory CRUD

    func addSubcategory(name: String, iconName: String, note: String = "", to category: OursCategory) async {
        let order = subcategoriesByCategory[category.id]?.count ?? 0
        var sub   = OursSubcategory(name: name, iconName: iconName, order: order,
                                    categoryID: category.id, note: note)
        sub = (try? await cloudKit.saveSubcategory(sub)) ?? sub
        subcategoriesByCategory[category.id, default: []].append(sub)
    }

    func updateNote(_ note: String, for subcategory: OursSubcategory, in category: OursCategory) {
        guard let idx = subcategoriesByCategory[category.id]?
            .firstIndex(where: { $0.id == subcategory.id }) else { return }
        subcategoriesByCategory[category.id]?[idx].note = note
        guard let updated = subcategoriesByCategory[category.id]?[idx] else { return }
        Task { try? await cloudKit.saveSubcategory(updated) }
    }

    func deleteSubcategory(_ sub: OursSubcategory, from category: OursCategory) async {
        try? await cloudKit.deleteSubcategory(sub)
        subcategoriesByCategory[category.id]?.removeAll { $0.id == sub.id }
        itemsBySubcategory.removeValue(forKey: sub.id)
    }

    func renameSubcategory(_ sub: OursSubcategory, to name: String, in category: OursCategory) {
        guard var subs = subcategoriesByCategory[category.id],
              let idx = subs.firstIndex(where: { $0.id == sub.id }) else { return }
        subs[idx].name = name
        subcategoriesByCategory[category.id] = subs
        Task { try? await cloudKit.saveSubcategory(subs[idx]) }
    }

    func moveSubcategory(in category: OursCategory, fromOffsets: IndexSet, toOffset: Int) {
        guard var subs = subcategoriesByCategory[category.id] else { return }
        subs.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for i in subs.indices { subs[i].order = i }
        subcategoriesByCategory[category.id] = subs
        Task { for sub in subs { try? await cloudKit.saveSubcategory(sub) } }
    }

    // MARK: - Item CRUD

    func addItem(title: String, notes: String, url: String, to sub: OursSubcategory) async {
        let order = itemsBySubcategory[sub.id]?.count ?? 0
        var item  = ListItem(title: title, notes: notes, url: url, order: order,
                             subcategoryID: sub.id)
        item = (try? await cloudKit.saveItem(item)) ?? item
        itemsBySubcategory[sub.id, default: []].append(item)
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
    }

    func renameItem(_ item: ListItem, to name: String, in sub: OursSubcategory) {
        guard var its = itemsBySubcategory[sub.id],
              let idx = its.firstIndex(where: { $0.id == item.id }) else { return }
        its[idx].title = name
        itemsBySubcategory[sub.id] = its
        Task { try? await cloudKit.saveItem(its[idx]) }
    }

    func moveItem(in subcategory: OursSubcategory, fromOffsets: IndexSet, toOffset: Int) {
        guard var its = itemsBySubcategory[subcategory.id] else { return }
        its.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for i in its.indices { its[i].order = i }
        itemsBySubcategory[subcategory.id] = its
        Task { for item in its { try? await cloudKit.saveItem(item) } }
    }

    // MARK: - Trip Block CRUD

    func loadBlocks(for trip: OursSubcategory) async {
        let blocks = (try? await cloudKit.fetchBlocks(for: trip.id)) ?? []
        blocksByTrip[trip.id] = blocks
        for block in blocks where block.type == .checklist {
            checkItemsByBlock[block.id] = (try? await cloudKit.fetchCheckItems(for: block.id)) ?? []
        }
    }

    func addBlock(title: String, type: TripBlockType, to trip: OursSubcategory) async {
        let order = blocksByTrip[trip.id]?.count ?? 0
        var block = TripBlock(tripID: trip.id, title: title, type: type, order: order)
        block = (try? await cloudKit.saveBlock(block)) ?? block
        blocksByTrip[trip.id, default: []].append(block)
        if type == .checklist { checkItemsByBlock[block.id] = [] }
    }

    func deleteBlock(_ block: TripBlock) async {
        try? await cloudKit.deleteBlock(block)
        blocksByTrip[block.tripID]?.removeAll { $0.id == block.id }
        checkItemsByBlock.removeValue(forKey: block.id)
    }

    func moveBlock(tripID: UUID, fromOffsets: IndexSet, toOffset: Int) {
        guard var blocks = blocksByTrip[tripID] else { return }
        blocks.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for i in blocks.indices { blocks[i].order = i }
        blocksByTrip[tripID] = blocks
        Task { for b in blocks { try? await cloudKit.saveBlock(b) } }
    }

    func updateBlockTitle(_ title: String, for block: TripBlock) {
        guard let idx = blocksByTrip[block.tripID]?.firstIndex(where: { $0.id == block.id }) else { return }
        blocksByTrip[block.tripID]?[idx].title = title
        guard let updated = blocksByTrip[block.tripID]?[idx] else { return }
        Task { try? await cloudKit.saveBlock(updated) }
    }

    func updateBlockText(_ text: String, for block: TripBlock) {
        guard let idx = blocksByTrip[block.tripID]?.firstIndex(where: { $0.id == block.id }) else { return }
        blocksByTrip[block.tripID]?[idx].text = text
        guard let updated = blocksByTrip[block.tripID]?[idx] else { return }
        Task { try? await cloudKit.saveBlock(updated) }
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
    }
}
