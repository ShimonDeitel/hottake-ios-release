import SwiftUI

/// The per-round reveal: the vote distribution bar chart, then each player's vote so the
/// table can see who was the most extreme on this statement.
struct RevealView: View {
    @ObservedObject var game: GameController

    private var result: RoundResult? { game.roundResult }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                if let result {
                    chartCard(result)
                    extremeCallout(result)
                    playerVotes(result)
                }
                nextButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 28)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("The Reveal").font(.title2.weight(.bold))
            Text(game.currentStatement?.text ?? "")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
        }
    }

    private func chartCard(_ result: RoundResult) -> some View {
        VStack(spacing: 14) {
            RevealBarChart(counts: result.counts)
            HStack {
                Text("Average")
                Spacer()
                Text(String(format: "%.1f / 5", result.average))
                    .foregroundStyle(Color.htAccent).fontWeight(.semibold)
            }
            .font(.subheadline)
        }
        .htCard()
    }

    @ViewBuilder
    private func extremeCallout(_ result: RoundResult) -> some View {
        if let name = result.mostExtreme.first {
            VStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.title3).foregroundStyle(Color.htAccent)
                Text(result.mostExtreme.count > 1
                     ? "\(result.mostExtreme.joined(separator: " & ")) had the hottest takes"
                     : "\(name) had the hottest take")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.htAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            Text("Everyone landed in the same place on this one.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func playerVotes(_ result: RoundResult) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(result.votes.enumerated()), id: \.offset) { _, vote in
                PlayerVoteRow(name: vote.playerName, value: vote.value,
                              highlighted: result.mostExtreme.contains(vote.playerName))
            }
        }
    }

    private var nextButton: some View {
        Button {
            game.advanceAfterReveal()
        } label: {
            Text(game.isLastRound ? "See Results" : "Next Statement")
                .frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .prominentButton()
        .padding(.top, 4)
        .accessibilityIdentifier("reveal-next")
    }
}
