import SwiftUI

/// Add 2-8 players and choose how many statements to play, then start.
struct SetupView: View {
    let deck: Deck

    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("hottake.players") private var savedPlayersData = Data()
    @AppStorage("hottake.rounds") private var roundCount = 5

    @State private var players: [String] = []
    @State private var newName = ""
    @State private var game: GameConfig?
    @FocusState private var nameFieldFocused: Bool

    private let minPlayers = 2
    private let maxPlayers = 8

    private var trimmedNew: String { newName.trimmingCharacters(in: .whitespaces) }
    private var canAdd: Bool { !trimmedNew.isEmpty && players.count < maxPlayers }
    private var canStart: Bool { players.count >= minPlayers && !deck.statements.isEmpty }

    private var roundOptions: [Int] {
        // Never offer more statements than the deck holds.
        [3, 5, 8, 12].filter { $0 <= deck.statements.count } + (deck.statements.count < 3 ? [deck.statements.count] : [])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HotTakeBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        deckBanner
                        playersSection
                        roundsSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) { startBar }
            .tint(Color.htAccent)
            .onAppear(perform: loadPlayers)
            .fullScreenCover(item: $game) { cfg in
                RoundView(config: cfg) { dismiss() }
            }
        }
    }

    private var deckBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: deck.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.htAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(deck.name).font(.headline)
                Text("\(deck.count) statements").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .htCard()
    }

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Players").font(.headline)
            Text("Add everyone playing. The phone passes around the circle.")
                .font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("Add a name", text: $newName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit(addPlayer)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.htField, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("player-name-field")

                Button(action: addPlayer) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .frame(width: 46, height: 46)
                        .background(canAdd ? Color.htAccent : Color.htField, in: Circle())
                        .foregroundStyle(canAdd ? .white : .secondary)
                }
                .disabled(!canAdd)
                .accessibilityIdentifier("add-player")
            }

            if players.isEmpty {
                Text("Add at least \(minPlayers) players to start.")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(players.enumerated()), id: \.offset) { idx, name in
                        HStack {
                            Image(systemName: "person.fill").foregroundStyle(.secondary)
                            Text(name)
                            Spacer()
                            Button {
                                Haptics.tap(); players.remove(at: idx); persistPlayers()
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Remove \(name)")
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Color.htCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    private var roundsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Statements this game").font(.headline)
            HStack(spacing: 10) {
                ForEach(roundOptions, id: \.self) { n in
                    Button {
                        Haptics.tap(); roundCount = n
                    } label: {
                        Text("\(n)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(roundCount == n ? Color.htAccent : Color.htCard, in: Capsule())
                            .foregroundStyle(roundCount == n ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var startBar: some View {
        Button(action: start) {
            Label("Start", systemImage: "play.fill")
                .frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .prominentButton()
        .disabled(!canStart)
        .opacity(canStart ? 1 : 0.5)
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .accessibilityIdentifier("setup-start")
    }

    // MARK: Actions

    private func addPlayer() {
        guard canAdd else { return }
        players.append(trimmedNew)
        newName = ""
        persistPlayers()
        Haptics.selection()
        nameFieldFocused = true
    }

    private func start() {
        guard canStart else { return }
        let effectiveRounds = min(max(1, roundCount), deck.statements.count)
        let picks = GameLogic.pickStatements(from: deck, count: effectiveRounds)
        game = GameConfig(deck: deck, players: players, statements: picks)
    }

    private func loadPlayers() {
        if let saved = try? JSONDecoder().decode([String].self, from: savedPlayersData), !saved.isEmpty {
            players = Array(saved.prefix(maxPlayers))
        }
        // Clamp the saved round count to what this deck supports.
        if let maxOpt = roundOptions.max(), roundCount > maxOpt { roundCount = maxOpt }
        if let minOpt = roundOptions.min(), roundCount < minOpt { roundCount = minOpt }
    }

    private func persistPlayers() {
        if let data = try? JSONEncoder().encode(players) { savedPlayersData = data }
    }
}
