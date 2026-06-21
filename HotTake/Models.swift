import Foundation
import SwiftData

/// One completed game (a sequence of rounds played by a fixed set of players).
/// All properties have defaults and there are no unique constraints.
@Model
final class GameSessionRecord {
    var id: UUID = UUID()
    var date: Date = Date.now
    var deckID: String = "classic"
    var deckName: String = "Classic"
    var playerNames: [String] = []
    var rounds: Int = 0
    /// The player who was the "most extreme" across the game (furthest from the middle, 3).
    var mostExtremePlayer: String = ""
    /// The player whose votes hugged the middle most (the diplomat).
    var mildestPlayer: String = ""

    init(id: UUID = UUID(), date: Date = .now, deckID: String = "classic",
         deckName: String = "Classic", playerNames: [String] = [], rounds: Int = 0,
         mostExtremePlayer: String = "", mildestPlayer: String = "") {
        self.id = id
        self.date = date
        self.deckID = deckID
        self.deckName = deckName
        self.playerNames = playerNames
        self.rounds = rounds
        self.mostExtremePlayer = mostExtremePlayer
        self.mildestPlayer = mildestPlayer
    }
}

/// One player's 1-5 vote on one statement, kept for building opinion profiles over time.
@Model
final class PlayerVoteRecord {
    var id: UUID = UUID()
    var date: Date = Date.now
    var gameID: UUID = UUID()
    var playerName: String = ""
    var deckID: String = "classic"
    var statementText: String = ""
    /// 1 (hate) ... 5 (love).
    var value: Int = 3

    init(id: UUID = UUID(), date: Date = .now, gameID: UUID = UUID(), playerName: String = "",
         deckID: String = "classic", statementText: String = "", value: Int = 3) {
        self.id = id
        self.date = date
        self.gameID = gameID
        self.playerName = playerName
        self.deckID = deckID
        self.statementText = statementText
        self.value = value
    }
}
