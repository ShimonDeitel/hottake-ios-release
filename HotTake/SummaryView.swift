import SwiftUI

/// End-of-game summary: who was the most extreme across the whole game, the per-player
/// hot-take ranking, and (Pro) a share button.
struct SummaryView: View {
    @ObservedObject var game: GameController
    let onDone: () -> Void

    @EnvironmentObject var store: Store

    @State private var showPaywall = false
    @State private var showShare = false

    private var result: GameResult { game.finalResult() }

    /// Players ranked by average extremity (hottest first).
    private var ranking: [(name: String, score: Int)] {
        game.players
            .map { (name: $0, score: Int((result.extremity(for: $0) / 2.0 * 100).rounded())) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                crown
                rankingCard
                actions
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 28)
        }
    }

    private var crown: some View {
        VStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Color.htAccent)
            Text("The extreme one is")
                .font(.title3).foregroundStyle(.secondary)
            Text(result.mostExtremePlayer)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            if !result.mildestPlayer.isEmpty, result.mildestPlayer != result.mostExtremePlayer {
                Text("Most diplomatic: \(result.mildestPlayer)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.htAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var rankingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hot Take score").font(.headline)
            ForEach(Array(ranking.enumerated()), id: \.offset) { idx, row in
                VStack(spacing: 6) {
                    HStack {
                        Text("\(idx + 1).").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        Text(row.name).font(.body.weight(idx == 0 ? .semibold : .regular))
                        Spacer()
                        Text("\(row.score)").font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.htAccent)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.htField).frame(height: 8)
                            Capsule().fill(Color.htAccent)
                                .frame(width: max(8, geo.size.width * CGFloat(row.score) / 100), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .htCard()
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.tap()
                if store.isPro { showShare = true } else { showPaywall = true }
            } label: {
                Label(store.isPro ? "Share Result" : "Share Result (Pro)",
                      systemImage: store.isPro ? "square.and.arrow.up" : "lock.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 2)
            }
            .softButton()
            .accessibilityIdentifier("summary-share")

            Button {
                Haptics.soft(); onDone()
            } label: {
                Text("Done").frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .prominentButton()
            .accessibilityIdentifier("summary-done")
        }
        .padding(.top, 4)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showShare) { ShareSheet(items: [shareText]) }
    }

    private var shareText: String {
        let lines = ranking.enumerated().map { "\($0.offset + 1). \($0.element.name) — \($0.element.score)" }
        return """
        Hot Take — \(game.deck.name)
        The extreme one: \(result.mostExtremePlayer)

        \(lines.joined(separator: "\n"))
        """
    }
}
