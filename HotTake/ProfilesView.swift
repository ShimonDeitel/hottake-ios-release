import SwiftUI

/// All-time opinion profiles built across every game, plus game history (Pro).
struct ProfilesView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false

    private var profiles: [OpinionProfile] { appModel.profiles }

    var body: some View {
        NavigationStack {
            ZStack {
                HotTakeBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        statsRow
                        if profiles.isEmpty {
                            emptyState
                        } else {
                            profilesCard
                            historySection
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(Color.htAccent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onAppear { appModel.refresh() }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            MetricTile(value: "\(appModel.totalGames)", label: "Games")
            MetricTile(value: "\(appModel.totalRounds)", label: "Statements")
            MetricTile(value: "\(profiles.count)", label: "Players")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No games yet").font(.headline)
            Text("Play a game and each player's opinion profile builds up here.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    private var profilesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hot Take leaderboard").font(.headline)
            ForEach(Array(profiles.enumerated()), id: \.element.id) { idx, p in
                VStack(spacing: 6) {
                    HStack {
                        Text("\(idx + 1).").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        Text(p.name).font(.body.weight(idx == 0 ? .semibold : .regular))
                        if p.extremeWins > 0 {
                            Label("\(p.extremeWins)", systemImage: "flame.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.htAccent)
                        }
                        Spacer()
                        Text("\(p.hotTakeScore)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.htAccent)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.htField).frame(height: 8)
                            Capsule().fill(Color.htAccent)
                                .frame(width: max(8, geo.size.width * CGFloat(p.hotTakeScore) / 100), height: 8)
                        }
                    }
                    .frame(height: 8)
                    Text("\(p.gamesPlayed) games · \(p.totalVotes) votes")
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .htCard()
    }

    @ViewBuilder
    private var historySection: some View {
        if store.isPro {
            let games = appModel.recentGames()
            if !games.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent games").font(.headline)
                    ForEach(games) { g in
                        HStack(spacing: 12) {
                            Image(systemName: "flame.fill")
                                .font(.subheadline).foregroundStyle(Color.htAccent).frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.deckName).font(.body)
                                Text("\(g.playerNames.count) players · \(g.rounds) statements")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(g.mostExtremePlayer).font(.subheadline.weight(.semibold))
                                Text(g.date, style: .date).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Color.htCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        } else {
            Button {
                Haptics.tap(); showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill").font(.caption.weight(.bold))
                    Text("Unlock game history with Hot Take Pro").font(.footnote)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color.htCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
