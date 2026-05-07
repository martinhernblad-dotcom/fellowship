import Foundation

// MARK: - OursCategory

struct OursCategory: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var colorHex1: String
    var colorHex2: String
    var iconName: String
    var order: Int

    init(id: UUID = UUID(), name: String, colorHex1: String, colorHex2: String,
         iconName: String, order: Int) {
        self.id = id; self.name = name; self.colorHex1 = colorHex1
        self.colorHex2 = colorHex2; self.iconName = iconName; self.order = order
    }

    static let seed: [OursCategory] = [
        OursCategory(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                     name: "Shopping",     colorHex1: "C9643A", colorHex2: "A84828",
                     iconName: "cart.fill",         order: 0),
        OursCategory(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                     name: "Resor",        colorHex1: "3E7D5E", colorHex2: "265C42",
                     iconName: "map.fill",           order: 1),
        OursCategory(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                     name: "Ekonomi",      colorHex1: "B8802A", colorHex2: "956018",
                     iconName: "creditcard.fill",    order: 2),
        OursCategory(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                     name: "Koder & Info", colorHex1: "467070", colorHex2: "2C5252",
                     iconName: "key.fill",           order: 3),
        OursCategory(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                     name: "Discover",     colorHex1: "6A8C52", colorHex2: "4A6C34",
                     iconName: "binoculars.fill",    order: 4),
        OursCategory(id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
                     name: "Recept",       colorHex1: "B85040", colorHex2: "943028",
                     iconName: "fork.knife",         order: 5),
    ]
}

// MARK: - Category content helpers

extension OursCategory {

    // Ekonomi and Discover look better with their SF Symbol than the Python art
    var useSystemIcon: Bool {
        id == UUID(uuidString: "00000000-0000-0000-0000-000000000003")! ||
        id == UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    }

    var artImageName: String {
        "art-\(name.components(separatedBy: " ").first!.lowercased())"
    }

    // Sheet title when adding a new entry
    var addListTitle: String {
        switch id {
        case UUID(uuidString: "00000000-0000-0000-0000-000000000002")!: return "Ny resa"
        case UUID(uuidString: "00000000-0000-0000-0000-000000000006")!: return "Nytt recept"
        default: return "Ny lista"
        }
    }

    // Resor uses TripDetailView (block-based); others use SubcategoryView
    var useTripView: Bool {
        id == UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    }

    // Koder & Info is reference material — no point ticking items off
    var isCheckable: Bool {
        id != UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    }

    // Section label for the note/instructions block — only Recept uses this now
    var noteLabel: String? {
        id == UUID(uuidString: "00000000-0000-0000-0000-000000000006")! ? "Instruktioner" : nil
    }

    var notePlaceholder: String {
        "Steg för steg-instruktioner…"
    }

    // Section label for the items/checklist block (nil = no header shown)
    var itemsLabel: String? {
        id == UUID(uuidString: "00000000-0000-0000-0000-000000000006")! ? "Ingredienser" : nil
    }

    var suggestedIcons: [String] {
        switch id {
        case UUID(uuidString: "00000000-0000-0000-0000-000000000001")!:
            return ["cart.fill","bag.fill","tag.fill","gift.fill","heart.fill","star.fill",
                    "house.fill","fork.knife","tshirt.fill","sparkles","figure.walk","camera.fill",
                    "book.fill","leaf.fill","pawprint.fill","music.note","dumbbell.fill",
                    "gamecontroller.fill","paintbrush.fill","creditcard.fill","scissors","photo.fill"]
        case UUID(uuidString: "00000000-0000-0000-0000-000000000002")!:
            return ["airplane","car.fill","map.fill","mappin.circle.fill","figure.walk","suitcase.fill",
                    "binoculars.fill","photo.fill","tent.fill","mountain.2.fill","camera.fill","star.fill",
                    "sunrise.fill","ticket.fill","globe","fork.knife","tram.fill","bicycle"]
        case UUID(uuidString: "00000000-0000-0000-0000-000000000003")!:
            return ["creditcard.fill","dollarsign.circle.fill","chart.bar.fill","house.fill","car.fill",
                    "fork.knife","cart.fill","bolt.fill","heart.fill","doc.text.fill","banknote.fill",
                    "building.columns.fill","airplane","tshirt.fill","phone.fill","wifi","leaf.fill"]
        case UUID(uuidString: "00000000-0000-0000-0000-000000000004")!:
            return ["key.fill","lock.fill","wifi","globe","iphone","creditcard.fill","doc.fill",
                    "person.fill","house.fill","airplane","car.fill","tv.fill","camera.fill",
                    "gamecontroller.fill","music.note","shield.fill","bell.fill","cloud.fill"]
        case UUID(uuidString: "00000000-0000-0000-0000-000000000005")!:
            return ["binoculars.fill","star.fill","film","music.note","book.fill","gamecontroller.fill",
                    "fork.knife","figure.walk","camera.fill","map.fill","paintbrush.fill","ticket.fill",
                    "sparkles","headphones","tv.fill","photo.fill","heart.fill","theatermasks.fill"]
        case UUID(uuidString: "00000000-0000-0000-0000-000000000006")!:
            return ["fork.knife","flame.fill","fish.fill","carrot.fill","hare.fill","leaf.fill",
                    "cart.fill","clock.fill","heart.fill","star.fill","book.fill","mug.fill",
                    "wineglass.fill","birthday.cake.fill","refrigerator.fill","hand.thumbsup.fill"]
        default:
            return ["folder.fill","list.bullet","cart.fill","heart.fill","star.fill","mappin.circle.fill",
                    "house.fill","bag.fill","tag.fill","doc.fill","camera.fill","music.note"]
        }
    }

    var namePrompt: String {
        switch id {
        case UUID(uuidString: "00000000-0000-0000-0000-000000000001")!: return "T.ex. ICA, Kläder, Önskelista…"
        case UUID(uuidString: "00000000-0000-0000-0000-000000000002")!: return "T.ex. Tokyo, Phuket, Roadtrip…"
        case UUID(uuidString: "00000000-0000-0000-0000-000000000003")!: return "T.ex. Mat, Hyra, Semester…"
        case UUID(uuidString: "00000000-0000-0000-0000-000000000004")!: return "T.ex. Netflix, WiFi, Hemförsäkring…"
        case UUID(uuidString: "00000000-0000-0000-0000-000000000005")!: return "T.ex. Filmer, Restauranger, Böcker…"
        case UUID(uuidString: "00000000-0000-0000-0000-000000000006")!: return "T.ex. Pasta carbonara, Tacos, Smoothie…"
        default: return "Namnge din lista…"
        }
    }
}

// MARK: - OursSubcategory

struct OursSubcategory: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var iconName: String
    var order: Int
    var categoryID: UUID
    var note: String    // instructions for recipes, trip notes for travel

    init(id: UUID = UUID(), name: String, iconName: String = "folder.fill",
         order: Int = 0, categoryID: UUID, note: String = "") {
        self.id = id; self.name = name; self.iconName = iconName
        self.order = order; self.categoryID = categoryID; self.note = note
    }

    // Backward-compatible decode: existing JSON won't have 'note'
    enum CodingKeys: String, CodingKey {
        case id, name, iconName, order, categoryID, note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(UUID.self,   forKey: .id)
        name       = try c.decode(String.self, forKey: .name)
        iconName   = try c.decode(String.self, forKey: .iconName)
        order      = try c.decode(Int.self,    forKey: .order)
        categoryID = try c.decode(UUID.self,   forKey: .categoryID)
        note       = (try? c.decode(String.self, forKey: .note)) ?? ""
    }
}

// MARK: - ListItem

struct ListItem: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var notes: String
    var url: String
    var isCompleted: Bool
    var order: Int
    var createdAt: Date
    var subcategoryID: UUID

    init(id: UUID = UUID(), title: String, notes: String = "", url: String = "",
         isCompleted: Bool = false, order: Int = 0, createdAt: Date = Date(),
         subcategoryID: UUID) {
        self.id = id; self.title = title; self.notes = notes; self.url = url
        self.isCompleted = isCompleted; self.order = order
        self.createdAt = createdAt; self.subcategoryID = subcategoryID
    }
}

// MARK: - Trip blocks (Resor category)

enum TripBlockType: String, Codable {
    case checklist
    case note
}

struct TripBlock: Identifiable, Hashable, Codable {
    var id: UUID
    var tripID: UUID
    var title: String
    var type: TripBlockType
    var order: Int
    var text: String    // content for note blocks

    init(id: UUID = UUID(), tripID: UUID, title: String,
         type: TripBlockType, order: Int = 0, text: String = "") {
        self.id = id; self.tripID = tripID; self.title = title
        self.type = type; self.order = order; self.text = text
    }
}

struct TripCheckItem: Identifiable, Hashable, Codable {
    var id: UUID
    var blockID: UUID
    var title: String
    var isChecked: Bool
    var order: Int

    init(id: UUID = UUID(), blockID: UUID, title: String,
         isChecked: Bool = false, order: Int = 0) {
        self.id = id; self.blockID = blockID; self.title = title
        self.isChecked = isChecked; self.order = order
    }
}

// MARK: - UserProfile

struct UserProfile: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var emoji: String
    var deviceID: String

    init(id: UUID = UUID(), name: String, emoji: String, deviceID: String) {
        self.id = id; self.name = name; self.emoji = emoji; self.deviceID = deviceID
    }
}
