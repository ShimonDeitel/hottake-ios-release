import SwiftUI

/// Pro feature: write and manage your own opinion statements, played as a "Your Takes" deck.
struct CustomStatementsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var texts: [String] = DeckCatalog.loadCustomTexts()
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canAdd: Bool { store.isPro && !trimmed.isEmpty && trimmed.count <= 120 }

    var body: some View {
        NavigationStack {
            ZStack {
                HotTakeBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        composer
                        if texts.isEmpty {
                            emptyState
                        } else {
                            list
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Your Takes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(Color.htAccent)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Write a statement").font(.headline)
            Text("Keep it a single opinion players can vote 1 to 5 on.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("e.g. Cereal counts as a soup.", text: $draft, axis: .vertical)
                .lineLimit(1...3)
                .focused($fieldFocused)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color.htField, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("custom-field")
            Button(action: add) {
                Label("Add", systemImage: "plus")
                    .frame(maxWidth: .infinity).padding(.vertical, 2)
            }
            .softButton()
            .disabled(!canAdd)
            .opacity(canAdd ? 1 : 0.5)
            .accessibilityIdentifier("custom-add")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 36, weight: .semibold)).foregroundStyle(.secondary)
            Text("No custom statements yet").font(.headline)
            Text("Add a few and they'll appear as a deck on the home screen.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private var list: some View {
        VStack(spacing: 8) {
            ForEach(Array(texts.enumerated()), id: \.offset) { idx, text in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "quote.opening")
                        .font(.caption).foregroundStyle(Color.htAccent).padding(.top, 3)
                    Text(text)
                    Spacer(minLength: 0)
                    Button {
                        Haptics.tap()
                        texts = DeckCatalog.removeCustom(at: IndexSet(integer: idx))
                    } label: {
                        Image(systemName: "trash").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Delete statement")
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color.htCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func add() {
        guard canAdd else { return }
        texts = DeckCatalog.addCustom(trimmed)
        draft = ""
        Haptics.selection()
        fieldFocused = true
    }
}
