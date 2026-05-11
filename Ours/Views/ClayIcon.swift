import SwiftUI

// CategoryIcon — dispatches to the correct clay icon struct based on the
// category's SF symbol iconName (the same string stored in OursCategory.iconName).
struct CategoryIcon: View {
    let iconName: String
    var size: CGFloat = 64

    var body: some View {
        switch iconName {
        case "bag.fill", "bag":
            ShoppingIcon(size: size)
        case "mountain.2.fill", "mountain":
            ResorIcon(size: size)
        case "creditcard.fill", "wallet":
            EkonomiIcon(size: size)
        case "key.fill", "key":
            KoderIcon(size: size)
        case "binoculars.fill", "binoculars":
            DiscoverIcon(size: size)
        case "pot.fill", "pot", "cookingpot":
            ReceptIcon(size: size)
        default:
            ShoppingIcon(size: size)
        }
    }
}
