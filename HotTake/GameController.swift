import SwiftUI

/// Drives a single pass-and-play game: walks players through each statement, collects 1-5 votes,
/// exposes the per-round reveal, and assembles the final game result. UI-facing state only —
/// the scoring math lives in `GameLogic` so it can be tested without this controller.
@MainActor
final class GameController: ObservableObject {
    enum Phase: Equatable {
        case voting        // players are casting votes for the current statement
        case reveal        // the bar chart + most-extreme reveal for the current statement
        case finished      // every statement played; show the game summary
    }

    let deck: Deck
    let players: [String]
    let statements: [Statement]

    @Published private(set) var phase: Phase = .voting
    @Published private(set) var roundIndex = 0          // 0-based statement index
    @Published private(set) var voterIndex = 0          // whose turn within the round
    @Published private(set) var currentVote = VoteScale.middle
    @Published private(set) var roundResult: RoundResult?

    /// Votes collected for the round currently being voted on.
    private var pendingVotes: [RoundVote] = []
    /// Every vote across the whole game (used for the final profile).
    private(set) var allVotes: [RoundVote] = []

    init(deck: Deck, players: [String], statements: [Statement]) {
        self.deck = deck
        self.players = players
        self.statements = statements
    }

    var totalRounds: Int { statements.count }
    var currentStatement: Statement? {
        statements.indices.contains(roundIndex) ? statements[roundIndex] : nil
    }
    var currentVoter: String {
        players.indices.contains(voterIndex) ? players[voterIndex] : ""
    }
    var isLastVoterInRound: Bool { voterIndex == players.count - 1 }
    var isLastRound: Bool { roundIndex == statements.count - 1 }

    /// Set the slider/segment selection without committing it.
    func setVote(_ value: Int) {
        currentVote = Swift.min(VoteScale.max, Swift.max(VoteScale.min, value))
    }

    /// Lock in the current voter's vote and advance to the next voter — or reveal the round.
    func submitVote() {
        guard phase == .voting else { return }
        pendingVotes.append(RoundVote(playerIndex: voterIndex, playerName: currentVoter,
                                      value: currentVote, statementIndex: roundIndex))
        if isLastVoterInRound {
            roundResult = GameLogic.roundResult(votes: pendingVotes)
            allVotes.append(contentsOf: pendingVotes)
            phase = .reveal
            Haptics.success()
        } else {
            voterIndex += 1
            currentVote = VoteScale.middle
            Haptics.selection()
        }
    }

    /// Move from a reveal to the next statement, or finish the game.
    func advanceAfterReveal() {
        guard phase == .reveal else { return }
        pendingVotes.removeAll()
        roundResult = nil
        if isLastRound {
            phase = .finished
            Haptics.success()
        } else {
            roundIndex += 1
            voterIndex = 0
            currentVote = VoteScale.middle
            phase = .voting
        }
    }

    /// The end-of-game opinion summary across every recorded vote.
    func finalResult() -> GameResult {
        GameLogic.gameResult(players: players, votes: allVotes, rounds: statements.count)
    }
}
