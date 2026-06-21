import SwiftUI

/// The live, full-screen game: voting -> reveal -> next statement -> final summary.
struct RoundView: View {
    @StateObject private var game: GameController
    let onFinishedToHome: () -> Void

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var handoffShown = true     // "pass to <player>" gate before each vote
    @State private var didRecord = false

    init(config: GameConfig, onFinishedToHome: @escaping () -> Void) {
        _game = StateObject(wrappedValue: GameController(deck: config.deck,
                                                         players: config.players,
                                                         statements: config.statements))
        self.onFinishedToHome = onFinishedToHome
    }

    var body: some View {
        ZStack {
            HotTakeBackground()
            switch game.phase {
            case .voting:
                if handoffShown { handoffScreen } else { votingScreen }
            case .reveal:
                RevealView(game: game)
            case .finished:
                SummaryView(game: game, onDone: finish)
            }
        }
        .overlay(alignment: .topTrailing) { closeButton }
        .onChange(of: game.phase) { _, newValue in
            if newValue == .voting { handoffShown = true }
            if newValue == .finished { recordGame() }
        }
    }

    private var closeButton: some View {
        Button {
            Haptics.tap(); dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2).foregroundStyle(.secondary).padding()
        }
        .accessibilityIdentifier("round-close")
        .accessibilityLabel("End game")
    }

    // MARK: Handoff gate — keeps each vote private as the phone passes.

    private var handoffScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            progressPill
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Color.htAccent)
            VStack(spacing: 8) {
                Text("Pass to").font(.title3).foregroundStyle(.secondary)
                Text(game.currentVoter).font(.system(size: 40, weight: .bold, design: .rounded))
            }
            Text("Tap when you're ready. Keep your vote to yourself.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
            Button {
                Haptics.soft(); handoffShown = false
            } label: {
                Text("I'm \(game.currentVoter)").frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .prominentButton()
            .padding(.horizontal, 28)
            .accessibilityIdentifier("handoff-ready")
            Spacer().frame(height: 20)
        }
        .padding()
    }

    // MARK: Voting

    private var votingScreen: some View {
        VStack(spacing: 20) {
            progressPill.padding(.top, 8)
            Spacer(minLength: 0)

            Text(game.currentStatement?.text ?? "")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .accessibilityIdentifier("statement-text")

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Text("How do you feel about this?")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(VoteScale.range, id: \.self) { value in
                        VoteButton(value: value, selected: game.currentVote == value) {
                            Haptics.selection(); game.setVote(value)
                        }
                    }
                }
                HStack {
                    Text("Hate it").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Love it").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)

            Button {
                game.submitVote()
            } label: {
                Text(game.isLastVoterInRound ? "Reveal Votes" : "Lock In")
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .prominentButton()
            .padding(.horizontal, 24)
            .accessibilityIdentifier("submit-vote")

            Spacer().frame(height: 16)
        }
        .padding(.top, 8)
    }

    private var progressPill: some View {
        HStack(spacing: 8) {
            Image(systemName: game.deck.symbol).font(.caption.weight(.bold))
            Text("Statement \(game.roundIndex + 1) of \(game.totalRounds)")
                .font(.subheadline.weight(.semibold))
            if game.phase == .voting && !handoffShown {
                Text("·").foregroundStyle(.secondary)
                Text(game.currentVoter).font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.htAccent)
            }
        }
        .htPill()
    }

    // MARK: Recording + finishing

    private func recordGame() {
        guard !didRecord else { return }
        didRecord = true
        let result = game.finalResult()
        appModel.recordGame(deck: game.deck, players: game.players,
                            statements: game.statements, votes: game.allVotes, result: result)
    }

    private func finish() {
        dismiss()
        onFinishedToHome()
    }
}
