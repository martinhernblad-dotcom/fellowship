import Foundation

enum RecipeImportError: Error {
    case invalidURL
    case fetchFailed
    case nothingUseful
}

enum RecipeURLImporter {

    static func importFrom(urlString: String) async throws -> RecipeDraft {
        guard let url = normalizedURL(from: urlString) else { throw RecipeImportError.invalidURL }

        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 "
                + "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
            throw RecipeImportError.fetchFailed
        }

        let html = decodeHTML(data: data, response: http)

        if let draft = parseJSONLD(html: html, source: url.absoluteString) {
            return draft
        }
        if let draft = parseFromBodyText(html: html, source: url.absoluteString) {
            return draft
        }
        throw RecipeImportError.nothingUseful
    }

    // MARK: - URL handling

    private static func normalizedURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return URL(string: trimmed)
        }
        return URL(string: "https://" + trimmed)
    }

    private static func decodeHTML(data: Data, response: HTTPURLResponse) -> String {
        if let encoding = response.textEncodingName,
           let cf = CFStringConvertIANACharSetNameToEncoding(encoding as CFString) as CFStringEncoding?,
           cf != kCFStringEncodingInvalidId {
            let nse = CFStringConvertEncodingToNSStringEncoding(cf)
            if let s = String(data: data, encoding: String.Encoding(rawValue: nse)) { return s }
        }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    // MARK: - JSON-LD path (preferred)

    private static func parseJSONLD(html: String, source: String) -> RecipeDraft? {
        for jsonText in extractJSONLDBlocks(from: html) {
            guard let data = jsonText.data(using: .utf8) else { continue }
            guard let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            else { continue }
            for node in flatten(parsed) {
                if let draft = recipeDraft(from: node, source: source) { return draft }
            }
        }
        return nil
    }

    private static func extractJSONLDBlocks(from html: String) -> [String] {
        let pattern = #"<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        else { return [] }
        let ns = html as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.matches(in: html, options: [], range: range).compactMap { m in
            guard m.numberOfRanges >= 2 else { return nil }
            return ns.substring(with: m.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func flatten(_ node: Any) -> [[String: Any]] {
        var out: [[String: Any]] = []
        if let dict = node as? [String: Any] {
            out.append(dict)
            if let graph = dict["@graph"] {
                out.append(contentsOf: flatten(graph))
            }
        } else if let arr = node as? [Any] {
            for el in arr { out.append(contentsOf: flatten(el)) }
        }
        return out
    }

    private static func recipeDraft(from node: [String: Any], source: String) -> RecipeDraft? {
        guard isRecipe(node) else { return nil }
        let name = (node["name"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""

        let ingredients = stringArray(node["recipeIngredient"])
            .map { decodeHTMLEntities(in: $0) }
            .filter { !$0.isEmpty }

        let instructions = parseInstructions(node["recipeInstructions"])

        guard !ingredients.isEmpty || !instructions.isEmpty || !name.isEmpty else { return nil }

        return RecipeDraft(
            name: name,
            instructions: instructions,
            ingredients: ingredients,
            iconHint: nil,
            sourceURL: source
        )
    }

    private static func isRecipe(_ node: [String: Any]) -> Bool {
        if let t = node["@type"] as? String, t == "Recipe" { return true }
        if let arr = node["@type"] as? [String], arr.contains("Recipe") { return true }
        return false
    }

    private static func parseInstructions(_ raw: Any?) -> String {
        if let s = raw as? String {
            return decodeHTMLEntities(in: stripTags(s))
        }
        if let arr = raw as? [Any] {
            var lines: [String] = []
            for entry in arr {
                if let s = entry as? String {
                    let v = decodeHTMLEntities(in: stripTags(s))
                    if !v.isEmpty { lines.append(v) }
                } else if let d = entry as? [String: Any] {
                    let type = (d["@type"] as? String) ?? ""
                    if type == "HowToSection" {
                        if let secName = d["name"] as? String, !secName.isEmpty {
                            lines.append(secName)
                        }
                        if let inner = d["itemListElement"] {
                            let nested = parseInstructions(inner)
                            if !nested.isEmpty { lines.append(nested) }
                        }
                    } else if let text = d["text"] as? String {
                        let v = decodeHTMLEntities(in: stripTags(text))
                        if !v.isEmpty { lines.append(v) }
                    } else if let name = d["name"] as? String {
                        lines.append(decodeHTMLEntities(in: stripTags(name)))
                    }
                }
            }
            return lines.joined(separator: "\n")
        }
        return ""
    }

    private static func stringArray(_ raw: Any?) -> [String] {
        if let s = raw as? String {
            return s.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        if let arr = raw as? [Any] {
            return arr.compactMap { $0 as? String }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        return []
    }

    // MARK: - HTML body fallback

    private static func parseFromBodyText(html: String, source: String) -> RecipeDraft? {
        let title = extractTitle(html: html)
        let bodyText = extractVisibleText(from: html)
        guard !bodyText.isEmpty else { return nil }

        let parsed = RecipeIngredientParser.parse(bodyText)
        guard !parsed.ingredients.isEmpty || !parsed.instructions.isEmpty else { return nil }

        return RecipeDraft(
            name: title,
            instructions: parsed.instructions,
            ingredients: parsed.ingredients,
            iconHint: nil,
            sourceURL: source
        )
    }

    private static func extractTitle(html: String) -> String {
        if let m = match(in: html, pattern: #"<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']"#) {
            return decodeHTMLEntities(in: m)
        }
        if let m = match(in: html, pattern: #"<title[^>]*>([\s\S]*?)</title>"#) {
            return decodeHTMLEntities(in: m).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private static func match(in s: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        else { return nil }
        let ns = s as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let m = regex.firstMatch(in: s, options: [], range: range), m.numberOfRanges >= 2
        else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    private static func extractVisibleText(from html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<noscript[\s\S]*?</noscript>"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"<(br|/p|/li|/h[1-6]|/div)[^>]*>"#,
                                   with: "\n", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        s = decodeHTMLEntities(in: s)
        s = s.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\n[ \t]+"#, with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\n{2,}"#, with: "\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripTags(_ s: String) -> String {
        s.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func decodeHTMLEntities(in s: String) -> String {
        var out = s
        let named: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'",
            "&apos;": "'", "&nbsp;": " ", "&aring;": "å", "&Aring;": "Å",
            "&auml;": "ä", "&Auml;": "Ä", "&ouml;": "ö", "&Ouml;": "Ö",
            "&eacute;": "é", "&Eacute;": "É"
        ]
        for (k, v) in named { out = out.replacingOccurrences(of: k, with: v) }
        out = decodeNumericEntities(out)
        return out
    }

    private static func decodeNumericEntities(_ s: String) -> String {
        let pattern = #"&#(x?)([0-9a-fA-F]+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return s }
        let ns = s as NSString
        let range = NSRange(location: 0, length: ns.length)
        var result = ""
        var cursor = 0
        for m in regex.matches(in: s, options: [], range: range) {
            let fullRange = m.range(at: 0)
            result += ns.substring(with: NSRange(location: cursor, length: fullRange.location - cursor))
            let isHex = ns.substring(with: m.range(at: 1)).lowercased() == "x"
            let numStr = ns.substring(with: m.range(at: 2))
            if let scalar = UInt32(numStr, radix: isHex ? 16 : 10),
               let unicode = Unicode.Scalar(scalar) {
                result.append(Character(unicode))
            }
            cursor = fullRange.location + fullRange.length
        }
        result += ns.substring(from: cursor)
        return result
    }
}
