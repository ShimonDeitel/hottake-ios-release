import XCTest
@testable import HotTake

/// Pure-logic tests for the game math, deck catalog, vote scale, and opinion-profile aggregation.
final class HotTakeTests: XCTestCase {

    // MARK: Vote scale

    func testExtremityIsDistanceFromNeutral() {
        XCTAssertEqual(VoteScale.extremity(1), 2)
        XCTAssertEqual(VoteScale.extremity(2), 1)
        XCTAssertEqual(VoteScale.extremity(3), 0)
        XCTAssertEqual(VoteScale.extremity(4), 1)
        XCTAssertEqual(VoteScale.extremity(5), 2)
    }

    // MARK: Round result — bar chart + most extreme

    func testRoundResultCountsAndAverage() {
        let votes = [
            RoundVote(playerIndex: 0, playerName: "A", value: 1),
            RoundVote(playerIndex: 1, playerName: "B", value: 3),
            RoundVote(playerIndex: 2, playerName: "C", value: 5),
            RoundVote(playerIndex: 3, playerName: "D", value: 5),
        ]
        let r = GameLogic.roundResult(votes: votes)
        XCTAssertEqual(r.counts, [1, 0, 1, 0, 2])     // values 1,3,5,5
        XCTAssertEqual(r.totalVotes, 4)
        XCTAssertEqual(r.average, (1 + 3 + 5 + 5) / 4.0, accuracy: 0.0001)
        XCTAssertEqual(r.maxCount, 2)
    }

    func testRoundResultIdentifiesMostExtremeAndMildest() {
        let votes = [
            RoundVote(playerIndex: 0, playerName: "Mild", value: 3),   // extremity 0
            RoundVote(playerIndex: 1, playerName: "Lean", value: 4),   // extremity 1
            RoundVote(playerIndex: 2, playerName: "Hot", value: 1),    // extremity 2
        ]
        let r = GameLogic.roundResult(votes: votes)
        XCTAssertEqual(r.mostExtreme, ["Hot"])
        XCTAssertEqual(r.mildest, ["Mild"])
    }

    func testRoundResultNoStandoutWhenEveryoneEquallyExtreme() {
        // All votes are equally far from neutral (1 and 5 both have extremity 2) → no standout.
        let votes = [
            RoundVote(playerIndex: 0, playerName: "A", value: 1),
            RoundVote(playerIndex: 1, playerName: "B", value: 5),
            RoundVote(playerIndex: 2, playerName: "C", value: 1),
        ]
        let r = GameLogic.roundResult(votes: votes)
        XCTAssertTrue(r.mostExtreme.isEmpty)
        XCTAssertTrue(r.mildest.isEmpty)
    }

    func testRoundResultTiesIncludeAllExtremePlayers() {
        let votes = [
            RoundVote(playerIndex: 0, playerName: "A", value: 5),   // extremity 2
            RoundVote(playerIndex: 1, playerName: "B", value: 1),   // extremity 2
            RoundVote(playerIndex: 2, playerName: "C", value: 3),   // extremity 0
        ]
        let r = GameLogic.roundResult(votes: votes)
        XCTAssertEqual(Set(r.mostExtreme), Set(["A", "B"]))
        XCTAssertEqual(r.mildest, ["C"])
    }

    func testRoundResultClampsOutOfRangeValues() {
        let votes = [
            RoundVote(playerIndex: 0, playerName: "A", value: 9),    // clamps to 5
            RoundVote(playerIndex: 1, playerName: "B", value: -3),   // clamps to 1
        ]
        let r = GameLogic.roundResult(votes: votes)
        XCTAssertEqual(r.counts, [1, 0, 0, 0, 1])
        XCTAssertEqual(r.average, 3.0, accuracy: 0.0001)
    }

    // MARK: Game result — who's the extreme one across a whole game

    func testGameResultPicksMostAndLeastExtremePlayer() {
        let players = ["Alex", "Sam", "Jordan"]
        let votes = [
            // round 1
            RoundVote(playerIndex: 0, playerName: "Alex", value: 1),    // ext 2
            RoundVote(playerIndex: 1, playerName: "Sam", value: 3),     // ext 0
            RoundVote(playerIndex: 2, playerName: "Jordan", value: 4),  // ext 1
            // round 2
            RoundVote(playerIndex: 0, playerName: "Alex", value: 5),    // ext 2
            RoundVote(playerIndex: 1, playerName: "Sam", value: 3),     // ext 0
            RoundVote(playerIndex: 2, playerName: "Jordan", value: 2),  // ext 1
        ]
        let result = GameLogic.gameResult(players: players, votes: votes, rounds: 2)
        XCTAssertEqual(result.mostExtremePlayer, "Alex")   // avg 2.0
        XCTAssertEqual(result.mildestPlayer, "Sam")        // avg 0.0
        XCTAssertEqual(result.extremity(for: "Alex"), 2.0, accuracy: 0.0001)
        XCTAssertEqual(result.extremity(for: "Jordan"), 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.rounds, 2)
    }

    func testGameResultStableTiebreakByPlayerOrder() {
        // Two players tie on extremity; the first in player order wins the "most extreme" slot.
        let players = ["Zoe", "Ada"]
        let votes = [
            RoundVote(playerIndex: 0, playerName: "Zoe", value: 5),
            RoundVote(playerIndex: 1, playerName: "Ada", value: 1),
        ]
        let result = GameLogic.gameResult(players: players, votes: votes, rounds: 1)
        XCTAssertEqual(result.mostExtremePlayer, "Zoe")
    }

    // MARK: Deck catalog

    func testBuiltInDecksLoadWithEnoughContent() {
        let decks = DeckCatalog.builtIn
        XCTAssertGreaterThanOrEqual(decks.count, 2, "should have a free + several Pro decks")
        let total = decks.reduce(0) { $0 + $1.count }
        XCTAssertGreaterThanOrEqual(total, 100, "must ship 100+ statements")
        // Exactly one free deck (Classic); the rest are Pro.
        XCTAssertEqual(decks.filter { !$0.isPro }.count, 1)
        XCTAssertTrue(decks.contains { $0.id == "classic" && !$0.isPro })
    }

    func testFreeUsersOnlySeeFreeDecks() {
        let free = DeckCatalog.availableDecks(isPro: false)
        XCTAssertTrue(free.allSatisfy { !$0.isPro })
        let pro = DeckCatalog.availableDecks(isPro: true)
        XCTAssertGreaterThan(pro.count, free.count)
    }

    func testStatementsAreFamilyFriendlyNonEmpty() {
        for deck in DeckCatalog.builtIn {
            for s in deck.statements {
                XCTAssertFalse(s.text.trimmingCharacters(in: .whitespaces).isEmpty)
                XCTAssertEqual(s.deckID, deck.id)
            }
        }
    }

    // MARK: Statement picking is deterministic with a seeded RNG

    func testPickStatementsRespectsCountAndIsDeterministic() {
        let deck = DeckCatalog.builtIn.first { $0.id == "classic" }!
        var rngA = SeededRNG(seed: 42)
        var rngB = SeededRNG(seed: 42)
        let a = GameLogic.pickStatements(from: deck, count: 5, using: &rngA)
        let b = GameLogic.pickStatements(from: deck, count: 5, using: &rngB)
        XCTAssertEqual(a.count, 5)
        XCTAssertEqual(a.map(\.id), b.map(\.id), "same seed → same picks")
    }

    func testPickStatementsCapsAtDeckSize() {
        let deck = DeckCatalog.builtIn.first { $0.id == "classic" }!
        let all = GameLogic.pickStatements(from: deck, count: 9999)
        XCTAssertEqual(all.count, deck.count)
    }

    // MARK: Opinion-profile aggregation (AppModel pure path)

    func testBuildProfilesAggregatesVotesAndWins() {
        let gid = UUID()
        let games = [
            GameSessionRecord(id: gid, deckID: "classic", deckName: "Classic",
                              playerNames: ["Alex", "Sam"], rounds: 2,
                              mostExtremePlayer: "Alex", mildestPlayer: "Sam")
        ]
        let votes = [
            PlayerVoteRecord(gameID: gid, playerName: "Alex", deckID: "classic", statementText: "x", value: 1),
            PlayerVoteRecord(gameID: gid, playerName: "Alex", deckID: "classic", statementText: "y", value: 5),
            PlayerVoteRecord(gameID: gid, playerName: "Sam", deckID: "classic", statementText: "x", value: 3),
            PlayerVoteRecord(gameID: gid, playerName: "Sam", deckID: "classic", statementText: "y", value: 3),
        ]
        let profiles = AppModel.buildProfiles(games: games, votes: votes)
        XCTAssertEqual(profiles.count, 2)
        // Sorted by extremity desc → Alex first.
        XCTAssertEqual(profiles.first?.name, "Alex")
        let alex = profiles.first { $0.name == "Alex" }!
        XCTAssertEqual(alex.avgExtremity, 2.0, accuracy: 0.0001)
        XCTAssertEqual(alex.hotTakeScore, 100)
        XCTAssertEqual(alex.extremeWins, 1)
        XCTAssertEqual(alex.gamesPlayed, 1)
        XCTAssertEqual(alex.totalVotes, 2)
        let sam = profiles.first { $0.name == "Sam" }!
        XCTAssertEqual(sam.hotTakeScore, 0)
        XCTAssertEqual(sam.extremeWins, 0)
    }
}

/// Tiny deterministic RNG for seeded tests (xorshift-style).
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xdeadbeef : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
