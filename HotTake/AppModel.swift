import Foundation
import SwiftData
import SwiftUI

/// A player's all-time opinion profile, derived from every recorded vote (never stored truth).
struct OpinionProfile: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let gamesPlayed: Int
    let totalVotes: Int
    /// Average extremity (0...2) — higher means hotter takes.
    let avgExtremity: Double
    /// How many times this player was crowned "most extreme" at the end of a game.
    let extremeWins: Int

    var hotTakeScore: Int { Int((avgExtremity / 2.0 * 100).rounded()) }   // 0...100
}

/// App state: owns the SwiftData store, records games + votes, and derives all-time
/// opinion profiles. Profiles/leaders are always derived from votes — never stored truth.
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published private(set) var totalGames = 0
    @Published private(set) var totalRounds = 0
    @Published private(set) var profiles: [OpinionProfile] = []

    init(container: ModelContainer) {
        self.container = container
        #if DEBUG
        seedIfRequested()
        #endif
        refresh()
    }

    // MARK: Container (local-only persistence; no CloudKit, no special capabilities)

    static func makeContainer() -> ModelContainer {
        let schema = Schema([GameSessionRecord.self, PlayerVoteRecord.self])
        let local = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        // Last resort so the app never crashes on launch.
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    // MARK: Recording a finished game

    /// Persists a completed game and its individual votes, then refreshes derived stats.
    func recordGame(deck: Deck, players: [String], statements: [Statement],
                    votes: [RoundVote], result: GameResult) {
        let ctx = container.mainContext
        let gameID = UUID()
        let game = GameSessionRecord(
            id: gameID, deckID: deck.id, deckName: deck.name, playerNames: players,
            rounds: statements.count, mostExtremePlayer: result.mostExtremePlayer,
            mildestPlayer: result.mildestPlayer)
        ctx.insert(game)
        // Each RoundVote carries its statement implicitly via order; we pass the text through
        // recordGame's caller assembling votes alongside statements, so store text on each.
        for v in votes {
            let text = v.statementIndex.flatMap { statements.indices.contains($0) ? statements[$0].text : nil } ?? ""
            ctx.insert(PlayerVoteRecord(gameID: gameID, playerName: v.playerName,
                                        deckID: deck.id, statementText: text, value: v.value))
        }
        try? ctx.save()
        refresh()
    }

    func recentGames(limit: Int = 50) -> [GameSessionRecord] {
        var d = FetchDescriptor<GameSessionRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        d.fetchLimit = limit
        return (try? container.mainContext.fetch(d)) ?? []
    }

    // MARK: Derived stats / opinion profiles

    func refresh() {
        let games = (try? container.mainContext.fetch(FetchDescriptor<GameSessionRecord>())) ?? []
        let votes = (try? container.mainContext.fetch(FetchDescriptor<PlayerVoteRecord>())) ?? []
        totalGames = games.count
        totalRounds = games.reduce(0) { $0 + $1.rounds }
        profiles = Self.buildProfiles(games: games, votes: votes)
    }

    /// Pure aggregation so it is easy to test in isolation.
    nonisolated static func buildProfiles(games: [GameSessionRecord],
                                          votes: [PlayerVoteRecord]) -> [OpinionProfile] {
        var totalExtremity: [String: Int] = [:]
        var voteCount: [String: Int] = [:]
        var gamesByPlayer: [String: Set<UUID>] = [:]
        var wins: [String: Int] = [:]

        for v in votes {
            let name = v.playerName
            guard !name.isEmpty else { continue }
            totalExtremity[name, default: 0] += VoteScale.extremity(v.value)
            voteCount[name, default: 0] += 1
            gamesByPlayer[name, default: []].insert(v.gameID)
        }
        for g in games where !g.mostExtremePlayer.isEmpty {
            wins[g.mostExtremePlayer, default: 0] += 1
        }

        return voteCount.keys.map { name in
            let c = voteCount[name] ?? 0
            let avg = c > 0 ? Double(totalExtremity[name] ?? 0) / Double(c) : 0
            return OpinionProfile(
                name: name,
                gamesPlayed: gamesByPlayer[name]?.count ?? 0,
                totalVotes: c,
                avgExtremity: avg,
                extremeWins: wins[name] ?? 0)
        }
        .sorted { lhs, rhs in
            if lhs.avgExtremity != rhs.avgExtremity { return lhs.avgExtremity > rhs.avgExtremity }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: Decks

    func availableDecks(isPro: Bool) -> [Deck] { DeckCatalog.availableDecks(isPro: isPro) }

    // MARK: Data deletion (Erase All Data)

    func deleteAllData() {
        let ctx = container.mainContext
        try? ctx.delete(model: PlayerVoteRecord.self)
        try? ctx.delete(model: GameSessionRecord.self)
        try? ctx.save()
        DeckCatalog.clearCustom()
        refresh()
    }

    // MARK: DEBUG seeding (compiled out of Release)

    #if DEBUG
    private func seedIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard env["HOTTAKE_SEED"] == "1" else { return }
        let ctx = container.mainContext
        if ((try? ctx.fetch(FetchDescriptor<GameSessionRecord>()))?.isEmpty ?? true) {
            let players = ["Alex", "Sam", "Jordan"]
            guard let deck = DeckCatalog.builtIn.first else { return }
            let picks = Array(deck.statements.prefix(4))
            let gameID = UUID()
            var votes: [RoundVote] = []
            for (i, s) in picks.enumerated() {
                for (pi, p) in players.enumerated() {
                    let value = [1, 5, 3, 4, 2][(i + pi) % 5]
                    votes.append(RoundVote(playerIndex: pi, playerName: p, value: value, statementIndex: i))
                    ctx.insert(PlayerVoteRecord(gameID: gameID, playerName: p, deckID: deck.id,
                                                statementText: s.text, value: value))
                }
            }
            let result = GameLogic.gameResult(players: players, votes: votes, rounds: picks.count)
            ctx.insert(GameSessionRecord(id: gameID, deckID: deck.id, deckName: deck.name,
                                         playerNames: players, rounds: picks.count,
                                         mostExtremePlayer: result.mostExtremePlayer,
                                         mildestPlayer: result.mildestPlayer))
            try? ctx.save()
        }
    }
    #endif
}
