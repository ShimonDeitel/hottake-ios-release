import Foundation

/// A single opinion statement that players vote on (1 hate ... 5 love).
struct Statement: Identifiable, Equatable, Hashable, Codable {
    var id: String
    var text: String
    var deckID: String

    init(id: String = UUID().uuidString, text: String, deckID: String) {
        self.id = id
        self.text = text
        self.deckID = deckID
    }
}

/// A themed collection of statements. The Classic deck is free; the rest are Pro.
/// A synthetic "Custom" deck holds the user's own statements (Pro).
struct Deck: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let blurb: String
    let symbol: String       // SF Symbol name
    let isPro: Bool
    let statements: [Statement]

    var count: Int { statements.count }

    static let customID = "custom"
}

// MARK: - JSON decoding shapes (match statements.json)

private struct DeckFile: Decodable {
    let version: Int
    let decks: [DeckDTO]
}

private struct DeckDTO: Decodable {
    let id: String
    let name: String
    let blurb: String
    let symbol: String
    let isPro: Bool
    let statements: [String]
}

/// Loads the bundled deck catalog and merges in the user's custom statements.
/// Pure, deterministic, and offline — the JSON ships in the app bundle.
enum DeckCatalog {
    private static let kCustom = "hottake.custom.statements"

    /// Built-in decks parsed from the bundled `statements.json`. Cached after first load.
    static let builtIn: [Deck] = loadBuiltIn()

    private static func loadBuiltIn() -> [Deck] {
        guard let url = Bundle.main.url(forResource: "statements", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(DeckFile.self, from: data) else {
            // Safe fallback so the app is always playable even if the resource is missing.
            return [fallbackClassic]
        }
        return file.decks.map { dto in
            Deck(id: dto.id, name: dto.name, blurb: dto.blurb, symbol: dto.symbol, isPro: dto.isPro,
                 statements: dto.statements.enumerated().map { i, text in
                     Statement(id: "\(dto.id)-\(i)", text: text, deckID: dto.id)
                 })
        }
    }

    private static let fallbackClassic = Deck(
        id: "classic", name: "Classic", blurb: "Everyday opinions to break the ice.",
        symbol: "flame.fill", isPro: false,
        statements: [
            "Pineapple belongs on pizza.", "Cereal counts as a soup.",
            "A hot dog is a sandwich.", "Dogs are better than cats.",
            "Coffee is better than tea."
        ].enumerated().map { i, t in Statement(id: "classic-\(i)", text: t, deckID: "classic") })

    /// The custom deck (Pro) built live from the user's saved statements. `nil` when empty.
    static func customDeck() -> Deck? {
        let texts = loadCustomTexts()
        guard !texts.isEmpty else { return nil }
        return Deck(id: Deck.customID, name: "Your Takes",
                    blurb: "Statements you wrote yourself.", symbol: "square.and.pencil",
                    isPro: true,
                    statements: texts.enumerated().map { i, t in
                        Statement(id: "\(Deck.customID)-\(i)", text: t, deckID: Deck.customID)
                    })
    }

    /// All decks visible to the user, honoring Pro gating. Free users see only the Classic deck.
    static func availableDecks(isPro: Bool) -> [Deck] {
        var decks = builtIn
        if isPro, let custom = customDeck() { decks.append(custom) }
        return isPro ? decks : decks.filter { !$0.isPro }
    }

    static func deck(id: String, isPro: Bool) -> Deck? {
        availableDecks(isPro: isPro).first { $0.id == id }
    }

    // MARK: Custom statements (Pro) — persisted locally.

    static func loadCustomTexts() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: kCustom),
              let texts = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return texts
    }

    /// Adds a trimmed, non-empty, de-duplicated statement. Returns the updated list.
    @discardableResult
    static func addCustom(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return loadCustomTexts() }
        var texts = loadCustomTexts()
        guard !texts.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            return texts
        }
        texts.append(trimmed)
        save(texts)
        return texts
    }

    @discardableResult
    static func removeCustom(at offsets: IndexSet) -> [String] {
        var texts = loadCustomTexts()
        texts.remove(atOffsets: offsets)
        save(texts)
        return texts
    }

    static func clearCustom() {
        UserDefaults.standard.removeObject(forKey: kCustom)
    }

    private static func save(_ texts: [String]) {
        if let data = try? JSONEncoder().encode(texts) {
            UserDefaults.standard.set(data, forKey: kCustom)
        }
    }
}

// MARK: - The vote scale (1 hate ... 5 love)

enum VoteScale {
    static let min = 1
    static let max = 5
    static let middle = 3
    static let range = Array(min...max)

    static func label(for value: Int) -> String {
        switch value {
        case 1: return "Hate it"
        case 2: return "Meh"
        case 3: return "Neutral"
        case 4: return "Like it"
        case 5: return "Love it"
        default: return "Neutral"
        }
    }

    static func symbol(for value: Int) -> String {
        switch value {
        case 1: return "hand.thumbsdown.fill"
        case 2: return "hand.thumbsdown"
        case 3: return "minus"
        case 4: return "hand.thumbsup"
        case 5: return "hand.thumbsup.fill"
        default: return "minus"
        }
    }

    /// How far a vote sits from neutral (0...2). The basis for "who's the extreme one".
    static func extremity(_ value: Int) -> Int { abs(value - middle) }
}
