import Foundation

// Typical ICA / Coop store layout, ordered from entrance to checkout.
// Lower rawValue = earlier in the walk-through.
enum ShoppingSection: Int, CaseIterable, Identifiable, Hashable {
    case fruktOchGront = 0
    case brod          = 1
    case chark         = 2
    case kottFagel     = 3
    case fiskSkaldjur  = 4
    case fardigmat     = 5
    case mejeri        = 6
    case frys          = 7
    case skafferi      = 8
    case snacksGodis   = 9
    case dryck         = 10
    case hushallHygien = 11
    case husdjur       = 12
    case ovrigt        = 99

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .fruktOchGront: return "Frukt & grönt"
        case .brod:          return "Bröd"
        case .chark:         return "Chark"
        case .kottFagel:     return "Kött & fågel"
        case .fiskSkaldjur:  return "Fisk & skaldjur"
        case .fardigmat:     return "Färdigmat"
        case .mejeri:        return "Mejeri"
        case .frys:          return "Frys"
        case .skafferi:      return "Skafferi"
        case .snacksGodis:   return "Snacks & godis"
        case .dryck:         return "Dryck"
        case .hushallHygien: return "Hushåll & hygien"
        case .husdjur:       return "Husdjur"
        case .ovrigt:        return "Övrigt"
        }
    }
}

enum GroceryCategorizer {

    /// Maps a free-text item title to the section of the store you'd typically find it in.
    /// Heuristic only — matches Swedish keywords with substring lookup.
    static func section(for title: String) -> ShoppingSection {
        let lower = title.lowercased()
        for (section, keywords) in keywordTable {
            if keywords.contains(where: { lower.contains($0) }) {
                return section
            }
        }
        return .ovrigt
    }

    // Order matters slightly: earlier entries win when an item could match
    // multiple sections (rare but possible — e.g. "fryst lax" → frys).
    private static let keywordTable: [(ShoppingSection, [String])] = [
        (.frys, [
            "fryst", "frusen", "frysta", "fryspizza", "glass", "isbitar"
        ]),
        (.fruktOchGront, [
            "äpple", "äpplen", "banan", "apelsin", "citron", "lime", "klementin",
            "vindruvor", "päron", "ananas", "kiwi", "mango", "avokado", "melon",
            "persika", "plommon", "körsbär", "dadlar",
            "jordgubbar", "blåbär", "hallon", "hjortron", "björnbär", "lingon",
            "vinbär",
            "tomat", "gurka", "paprika", "morot", "potatis", "sötpotatis",
            "palsternacka", "rödbeta", "lök", "vitlök", "purjolök", "schalottenlök",
            "salladslök", "ingefära",
            "sallat", "sallad", "spenat", "ruccola", "mangold",
            "broccoli", "blomkål", "vitkål", "rödkål", "brysselkål",
            "svamp", "champinjon", "sparris", "selleri", "fänkål", "majs",
            "ärtor", "gröna bönor", "zucchini", "squash", "aubergine", "pumpa",
            "rosmarin", "basilika", "persilja", "koriander", "mynta", "timjan",
            "dill", "gräslök"
        ]),
        (.brod, [
            "bröd", "rågbröd", "ciabatta", "baguette", "fralla", "knäckebröd",
            "kavring", "hönökaka", "polarbröd", "tunnbröd", "kanelbulle",
            "tekaka", "pågen", "wasa"
        ]),
        (.chark, [
            "skinka", "salami", "leverpastej", "rostbiff", "bacon", "kassler",
            "prosciutto", "chorizo", "kalkonpålägg", "ostskinka", "falukorv",
            "prinskorv", "bratwurst", "pålägg"
        ]),
        (.kottFagel, [
            "nötfärs", "fläskfärs", "blandfärs", "köttfärs", "biff", "oxfilé",
            "fläskfilé", "fläskkarré", "kotletter", "stek", "lammkött",
            "lammkotletter", "kalvkött", "kyckling", "kycklingfilé",
            "kycklinglår", "kalkon", "kalkonfärs", "kalkonbröst", "köttbullar",
            "wallenbergare", "korv"
        ]),
        (.fiskSkaldjur, [
            "lax", "gravad lax", "rökt lax", "torsk", "kolja", "sej", "gös",
            "abborre", "makrill", "sill", "strömming", "tonfisk", "kaviar",
            "rom", "räkor", "kräftor", "hummer", "krabba", "musslor", "ostron",
            "krabbsticks", "sushi", "fiskpinnar"
        ]),
        (.fardigmat, [
            "pizza", "lasagne", "pyttipanna", "färdigmat", "ugnsmat", "soppa",
            "ramen", "köttbullspasta"
        ]),
        (.mejeri, [
            "mjölk", "lättmjölk", "mellanmjölk", "havremjölk", "sojamjölk",
            "mandelmjölk",
            "grädde", "vispgrädde", "matlagningsgrädde", "crème fraîche",
            "creme fraiche", "créme fraîche",
            "yoghurt", "gräddfil", "filmjölk", "kvarg", "kesella", "skyr",
            "smör", "margarin", "lättmargarin", "bregott", "lätta",
            "ost", "cheddar", "brie", "camembert", "mozzarella", "halloumi",
            "fetaost", "parmesan", "parmesanost", "herrgård", "prästost",
            "gouda", "västerbottensost", "färskost", "philadelphia",
            "ägg", "äggen", "tofu"
        ]),
        (.skafferi, [
            "pasta", "spagetti", "makaroner", "penne", "lasagneplatt",
            "tortellini",
            "ris", "basmatiris", "jasminris", "råris", "couscous", "bulgur",
            "quinoa",
            "mjöl", "vetemjöl", "rågmjöl", "dinkelmjöl", "havremjöl",
            "mandelmjöl", "pannkaksmix",
            "havregryn", "müsli", "cornflakes", "flingor", "frukostflingor",
            "granola",
            "socker", "salt", "peppar", "kryddpeppar",
            "olja", "rapsolja", "olivolja", "kokosolja", "sesamolja",
            "vinäger", "äppelcidervinäger", "balsamico", "balsamvinäger",
            "soja", "sojasås", "fisksås", "ostron sås", "hoisin", "worcestershire",
            "tomatkonserv", "krossade tomater", "hela tomater",
            "passerade tomater", "tomatpuré",
            "bönor", "kikärtor", "linser",
            "kokosmjölk",
            "sylt", "marmelad", "honung", "lönnsirap", "kakao", "nutella",
            "choklad",
            "kaffe", "te", "buljong", "fond", "kalvfond", "kycklingbuljong",
            "grönsaksbuljong",
            "krydda", "curry", "kanel", "vanilj",
            "kex", "smörgåsgurka", "majonnäs", "ketchup", "senap", "dijonsenap",
            "sriracha", "sweet chili",
            "jordnötssmör", "tahini", "hummus",
            "konserv"
        ]),
        (.snacksGodis, [
            "chips", "popcorn", "godis", "lakrits", "polkagris", "praliner",
            "ostbågar", "tortillachips"
        ]),
        (.dryck, [
            "läsk", "coca-cola", "cola", "fanta", "sprite", "pepsi",
            "ramlösa", "loka", "vichy", "mineralvatten",
            "juice", "apelsinjuice", "äppeljuice", "saft", "smoothie",
            "öl", "ipa", "lager", "pilsner", "cider",
            "vin", "rödvin", "vitt vin", "rosévin", "mousserande", "champagne",
            "prosecco",
            "whisky", "vodka", "gin", "tequila", "sake"
        ]),
        (.hushallHygien, [
            "tvättmedel", "sköljmedel", "diskmedel", "maskindiskmedel",
            "fönsterputs",
            "toapapper", "hushållspapper", "servett", "soppåsar",
            "tvål", "schampo", "balsam", "dusch", "duschcreme",
            "tandkräm", "tandborste", "tandtråd", "munvatten", "deo",
            "deodorant", "rakhyvel", "after shave",
            "blöjor", "våtservetter", "tampong", "binda", "mensskydd",
            "hudkräm", "solkräm", "lipbalm",
            "rengöring", "kalkborttagning", "ugnsrengöring",
            "batterier", "glödlampor"
        ]),
        (.husdjur, [
            "hundmat", "kattmat", "kattsand", "hundgodis", "fågelmat"
        ])
    ]
}
