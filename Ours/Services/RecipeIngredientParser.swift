import Foundation

struct ParsedRecipeBody {
    var ingredients: [String]
    var instructions: String
}

enum RecipeIngredientParser {

    // Order matters: longer tokens first so "tsk" doesn't shadow "msk".
    private static let units: [String] = [
        "matskedar", "matsked", "tesked", "teskedar", "matskedar", "krmar", "kryddmått",
        "msk", "tsk", "krm", "dl", "ml", "cl", "kg", "hg",
        "nypa", "nypor", "klyfta", "klyftor", "paket", "burk", "burkar",
        "ask", "askar", "kruka", "krukor", "knippe", "klick", "skiva", "skivor",
        "st", "styck", "stycken",
        "tablespoons", "tablespoon", "teaspoons", "teaspoon",
        "tbsp", "tbs", "tsp", "cups", "cup", "ounces", "ounce", "oz", "lb", "lbs", "g", "l"
    ]

    private static let sectionMarkersIngredients: [String] = [
        "ingredienser", "ingrediens", "ingredients", "ingredient", "du behöver", "you'll need", "you will need"
    ]

    private static let sectionMarkersInstructions: [String] = [
        "gör så här", "tillagning", "instruktioner", "instruktion", "så här gör du", "method",
        "instructions", "directions", "steps", "preparation", "tillvägagångssätt"
    ]

    private static let leadingNumberPattern: String =
        #"^\s*([0-9¼½¾⅓⅔⅛⅜⅝⅞]+(?:\s*[,./\-–]\s*[0-9¼½¾⅓⅔⅛⅜⅝⅞]+)?)\s*"#

    static func parse(_ rawText: String) -> ParsedRecipeBody {
        let lines = normalize(rawText)
        guard !lines.isEmpty else { return ParsedRecipeBody(ingredients: [], instructions: "") }

        var section: Section = .unknown
        var ingredients: [String] = []
        var instructionLines: [String] = []
        var leadingFreeText: [String] = []

        for line in lines {
            let lower = line.lowercased()

            if let detected = detectSection(lower) {
                section = detected
                continue
            }

            switch section {
            case .ingredients:
                if let cleaned = cleanIngredientLine(line) { ingredients.append(cleaned) }
            case .instructions:
                instructionLines.append(stripStepPrefix(line))
            case .unknown:
                if looksLikeIngredient(line) {
                    if let cleaned = cleanIngredientLine(line) { ingredients.append(cleaned) }
                } else {
                    leadingFreeText.append(line)
                }
            }
        }

        if instructionLines.isEmpty && !leadingFreeText.isEmpty {
            let prose = leadingFreeText.filter { !looksLikeIngredient($0) }
            instructionLines = prose.map(stripStepPrefix)
        }

        let instructions = instructionLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedRecipeBody(ingredients: ingredients, instructions: instructions)
    }

    // MARK: - Helpers

    private enum Section { case unknown, ingredients, instructions }

    private static func normalize(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func detectSection(_ lower: String) -> Section? {
        let stripped = lower
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespaces)
        if stripped.count > 28 { return nil }
        if sectionMarkersIngredients.contains(where: { stripped == $0 || stripped.hasPrefix($0) }) {
            return .ingredients
        }
        if sectionMarkersInstructions.contains(where: { stripped == $0 || stripped.hasPrefix($0) }) {
            return .instructions
        }
        return nil
    }

    private static func looksLikeIngredient(_ line: String) -> Bool {
        guard line.count < 90 else { return false }
        if line.range(of: leadingNumberPattern, options: .regularExpression) != nil { return true }
        let lower = line.lowercased()
        return units.contains { unit in
            lower.range(of: "\\b\(NSRegularExpression.escapedPattern(for: unit))\\b",
                        options: .regularExpression) != nil
                && line.count < 60
        }
    }

    private static func cleanIngredientLine(_ line: String) -> String? {
        var s = line
        s = s.replacingOccurrences(of: "•", with: "")
        s = s.replacingOccurrences(of: "·", with: "")
        s = s.replacingOccurrences(of: "*", with: "")
        s = s.replacingOccurrences(of: #"^\s*[-–—]\s*"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func stripStepPrefix(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"^\s*(?:steg\s*)?\d+[\.\):]?\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }
}
