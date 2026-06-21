import Foundation

/// A player's vote within an in-progress round.
struct RoundVote: Equatable {
    let playerIndex: Int
    let playerName: String
    let value: Int                  // 1...5
    /// Index of the statement this vote was cast on (used when persisting). Optional for
    /// per-round computations that do not care which statement it was.
    var statementIndex: Int? = nil
}

/// The computed reveal for one round: the bar-chart distribution plus who was most extreme.
struct RoundResult: Equatable {
    /// counts[i] = number of votes equal to (i + 1), for i in 0..<5.
    let counts: [Int]
    let average: Double
    /// Players furthest from neutral (3). Ties included — usually one name.
    let mostExtreme: [String]
    /// Players closest to neutral.
    let mildest: [String]
    let votes: [RoundVote]

    var totalVotes: Int { counts.reduce(0, +) }
    var maxCount: Int { counts.max() ?? 0 }
}

/// The end-of-game opinion summary across every round played.
struct GameResult: Equatable {
    /// Average extremity (0...2) per player across the game.
    let extremityByPlayer: [String: Double]
    let mostExtremePlayer: String
    let mildestPlayer: String
    let rounds: Int

    func extremity(for player: String) -> Double { extremityByPlayer[player] ?? 0 }
}

/// Pure, deterministic party-game logic. No UI, no I/O — fully unit-testable.
enum GameLogic {

    /// Builds the bar chart + extremity reveal for a single finished round.
    /// `votes` must be non-empty; values are clamped into 1...5 defensively.
    static func roundResult(votes: [RoundVote]) -> RoundResult {
        var counts = Array(repeating: 0, count: VoteScale.max)   // index 0 -> value 1
        var sum = 0
        for v in votes {
            let clamped = Swift.min(VoteScale.max, Swift.max(VoteScale.min, v.value))
            counts[clamped - 1] += 1
            sum += clamped
        }
        let average = votes.isEmpty ? 0 : Double(sum) / Double(votes.count)

        let extremities = votes.map { (name: $0.playerName, e: VoteScale.extremity($0.value)) }
        let maxE = extremities.map(\.e).max() ?? 0
        let minE = extremities.map(\.e).min() ?? 0
        // Only call someone "most extreme" when there is a real spread (maxE > minE);
        // if everyone voted equally extreme there is no standout.
        let mostExtreme = maxE > minE ? namesWith(extremities, equalTo: maxE) : []
        let mildest = maxE > minE ? namesWith(extremities, equalTo: minE) : []

        return RoundResult(counts: counts, average: average,
                           mostExtreme: mostExtreme, mildest: mildest, votes: votes)
    }

    private static func namesWith(_ pairs: [(name: String, e: Int)], equalTo target: Int) -> [String] {
        // Preserve player order and de-duplicate (two players could share a name).
        var seen = Set<String>()
        var result: [String] = []
        for p in pairs where p.e == target {
            if seen.insert(p.name).inserted { result.append(p.name) }
        }
        return result
    }

    /// Aggregates every recorded vote of a game into a per-player opinion profile.
    /// `rounds` is the number of statements played. `players` defines the canonical order
    /// so the "winner" tiebreak is stable.
    static func gameResult(players: [String], votes: [RoundVote], rounds: Int) -> GameResult {
        var totals: [String: Int] = [:]
        var counts: [String: Int] = [:]
        for p in players { totals[p] = 0; counts[p] = 0 }
        for v in votes {
            totals[v.playerName, default: 0] += VoteScale.extremity(v.value)
            counts[v.playerName, default: 0] += 1
        }
        var avg: [String: Double] = [:]
        for p in players {
            let c = counts[p] ?? 0
            avg[p] = c > 0 ? Double(totals[p] ?? 0) / Double(c) : 0
        }
        // Stable winners: highest/lowest average extremity, ties broken by player order.
        let mostExtreme = players.max(by: { (avg[$0] ?? 0) < (avg[$1] ?? 0) }) ?? ""
        let mildest = players.min(by: { (avg[$0] ?? 0) < (avg[$1] ?? 0) }) ?? ""
        return GameResult(extremityByPlayer: avg, mostExtremePlayer: mostExtreme,
                          mildestPlayer: mildest, rounds: rounds)
    }

    /// Picks `count` statements from a deck for a game, in a shuffled order.
    /// Deterministic when a seeded generator is supplied (used by tests).
    static func pickStatements(from deck: Deck, count: Int,
                               using generator: inout some RandomNumberGenerator) -> [Statement] {
        let shuffled = deck.statements.shuffled(using: &generator)
        return Array(shuffled.prefix(Swift.max(0, count)))
    }

    static func pickStatements(from deck: Deck, count: Int) -> [Statement] {
        var rng = SystemRandomNumberGenerator()
        return pickStatements(from: deck, count: count, using: &rng)
    }
}
