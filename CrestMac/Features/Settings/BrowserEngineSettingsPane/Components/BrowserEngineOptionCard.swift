import SwiftUI

/// The entire engine card is a keyboard-accessible selection control.
struct BrowserEngineOptionCard: View {
    // MARK: - Variables

    let option: BrowserEngineOption
    let isSelected: Bool
    let isRecommended: Bool
    let isAvailable: Bool
    let choose: () -> Void

    // MARK: - Actions - Presentation

    var body: some View {
        Button(action: choose) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(option.logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.engine.title).font(.title3.weight(.semibold))
                        if isRecommended {
                            Text("Recommended").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .accessibilityHidden(true)
                }
                Text(option.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(option.benefits, id: \.symbol) { benefit in
                        Label {
                            Text(benefit.title)
                        } icon: {
                            Image(systemName: benefit.symbol).frame(width: 20)
                        }
                        .font(.callout)
                    }
                }
                Text(
                    isAvailable
                        ? (isSelected ? "Default for new pages" : "Use for new pages") : "Unavailable in this build"
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("default-engine-\(option.engine.name)")
    }
}
