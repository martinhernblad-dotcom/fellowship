import Foundation

struct RecipeDraft: Equatable {
    var name: String
    var instructions: String
    var ingredients: [String]
    var iconHint: String?
    var sourceURL: String?

    static let empty = RecipeDraft(name: "", instructions: "", ingredients: [])

    var hasContent: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            || !instructions.trimmingCharacters(in: .whitespaces).isEmpty
            || !ingredients.isEmpty
    }
}
