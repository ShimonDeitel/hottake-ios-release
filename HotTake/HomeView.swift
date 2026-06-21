import SwiftUI

/// Carries the chosen deck and player roster from Setup into the live game.
struct GameConfig: Identifiable {
    let id = UUID()
    let deck: Deck
    let players: [String]
    let statements: [Statement]
}

struct HomeView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @AppStorage("hottake.deck") private var deckID = "classic"

    @State private var showSetup = false
    @State private var showProfiles = false
    @State private var showSettings = false
    @State private var showPaywall = false

    private var decks: [Deck] { DeckCatalog.builtIn + customDeckIfAny }
    private var customDeckIfAny: [Deck] {
        (store.isPro ? DeckCatalog.customDeck().map { [$0] } : nil) ?? []
    }

    private var selectedDeck: Deck {
        let d = DeckCatalog.deck(id: deckID, isPro: store.isPro)
        return d ?? DeckCatalog.builtIn.first ?? decks[0]
    }

    var body: some View {
        ZStack {
            HotTakeBackground()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    titleBlock
                    deckList
                    startButton
                    customDeckPrompt
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .sheet(isPresented: $showSetup) {
            SetupView(deck: selectedDeck)
        }
        .sheet(isPresented: $showProfiles) { ProfilesView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear { appModel.refresh() }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color.htAccent)
                Text(appModel.totalGames > 0 ? "\(appModel.totalGames) games played" : "First game")
                    .font(.subheadline.weight(.semibold))
            }
            .htPill()

            Spacer()

            Button { Haptics.tap(); showProfiles = true } label: {
                Image(systemName: "person.2.fill").font(.title3)
            }
            .tint(.primary)
            .padding(.trailing, 14)
            .accessibilityIdentifier("open-profiles")
            .accessibilityLabel("Opinion profiles")

            Button { Haptics.tap(); showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.title3)
            }
            .tint(.primary)
            .accessibilityIdentifier("open-settings")
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("Hot Take")
                .font(.system(size: 38, weight: .bold, design: .rounded))
            Text("Pick a deck, then pass the phone.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var deckList: some View {
        VStack(spacing: 10) {
            ForEach(decks) { deck in
                let locked = deck.isPro && !store.isPro
                DeckCard(deck: deck, selected: deck.id == selectedDeck.id, locked: locked) {
                    Haptics.tap()
                    if locked { showPaywall = true } else { deckID = deck.id }
                }
            }
        }
    }

    private var startButton: some View {
        Button {
            Haptics.soft(); showSetup = true
        } label: {
            Label("Start Game", systemImage: "play.fill")
                .frame(maxWidth: .infinity).padding(.vertical, 4)
        }
        .prominentButton()
        .accessibilityIdentifier("start-game")
        .padding(.top, 4)
    }

    @ViewBuilder
    private var customDeckPrompt: some View {
        if !store.isPro {
            Button {
                Haptics.tap(); showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill").font(.caption.weight(.bold))
                    Text("Unlock all decks, custom statements, history & sharing")
                        .font(.footnote)
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
