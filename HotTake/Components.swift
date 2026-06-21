import SwiftUI

/// A selectable deck card on the Home screen; shows a lock when the deck is Pro and the user isn't.
struct DeckCard: View {
    let deck: Deck
    let selected: Bool
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: deck.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? .white : Color.htAccent)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(deck.name).font(.headline)
                        if locked {
                            Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold))
                        }
                    }
                    Text(deck.blurb)
                        .font(.caption)
                        .foregroundStyle(selected ? .white.opacity(0.85) : .secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("\(deck.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(selected ? .white.opacity(0.9) : .secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(
                selected ? Color.htAccent : Color.htCard,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("deck-\(deck.id)")
    }
}

/// One of the five 1-5 vote buttons (hate ... love).
struct VoteButton: View {
    let value: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: VoteScale.symbol(for: value))
                    .font(.system(size: 22, weight: .semibold))
                Text("\(value)")
                    .font(.caption.weight(.bold).monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                selected ? Color.htAccent : Color.htCard,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("vote-\(value)")
        .accessibilityLabel("\(VoteScale.label(for: value))")
    }
}

/// The reveal bar chart: one bar per value 1...5, height scaled to the biggest bucket.
struct RevealBarChart: View {
    let counts: [Int]                 // length 5
    var maxHeight: CGFloat = 150

    private var maxCount: Int { Swift.max(1, counts.max() ?? 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(0..<counts.count, id: \.self) { i in
                let value = i + 1
                let c = counts[i]
                VStack(spacing: 8) {
                    Text(c > 0 ? "\(c)" : " ")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(c > 0 ? Color.htAccent : Color.htField)
                        .frame(height: barHeight(for: c))
                    Image(systemName: VoteScale.symbol(for: value))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("\(value)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func barHeight(for count: Int) -> CGFloat {
        let minBar: CGFloat = 6
        guard count > 0 else { return minBar }
        return minBar + (maxHeight - minBar) * CGFloat(count) / CGFloat(maxCount)
    }
}

/// A small labelled metric tile (Home / Profiles).
struct MetricTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.htAccent)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.htCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// A row showing a player's name with their colored vote chip (used on the per-player reveal).
struct PlayerVoteRow: View {
    let name: String
    let value: Int
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: highlighted ? "flame.fill" : "person.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(highlighted ? Color.htAccent : .secondary)
                .frame(width: 22)
            Text(name).font(.body.weight(highlighted ? .semibold : .regular))
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: VoteScale.symbol(for: value))
                    .font(.subheadline.weight(.semibold))
                Text(VoteScale.label(for: value)).font(.subheadline)
            }
            .foregroundStyle(highlighted ? Color.htAccent : .primary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.htCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Wraps UIActivityViewController so the reveal can be shared (Pro).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
