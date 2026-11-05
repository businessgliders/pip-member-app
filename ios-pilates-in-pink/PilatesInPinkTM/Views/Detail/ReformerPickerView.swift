import SwiftUI

/// Mirrors the real room: front of room at the top, reformers placed by row/column.
struct ReformerPickerView: View {
    let stations: [Station]
    let stateFor: (Station) -> ReformerTileState
    let onTap: (Station) -> Void

    private var rows: [Int] {
        Array(Set(stations.map(\.row))).sorted()
    }

    private var columns: [Int] {
        let maxColumn = stations.map(\.column).max() ?? 2
        return Array(1...max(maxColumn, 1))
    }

    var body: some View {
        VStack(spacing: 10) {
            frontOfRoom
                .padding(.bottom, 6)

            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(columns, id: \.self) { column in
                        if let station = stations.first(where: { $0.row == row && $0.column == column }) {
                            ReformerTile(station: station, state: stateFor(station)) {
                                onTap(station)
                            }
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                        }
                    }
                }
            }

            legend
                .padding(.top, 8)
        }
    }

    private var frontOfRoom: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Theme.ink.opacity(0.85))
                .frame(width: 120, height: 3)
            EyebrowText("Front of room", size: 11)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var legend: some View {
        HStack(spacing: 18) {
            legendItem(fill: Theme.card, stroke: Theme.hairline, text: "Open")
            legendItem(fill: Theme.pink, stroke: .clear, text: "Selected")
            legendItem(fill: Theme.taken, stroke: .clear, text: "Taken")
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func legendItem(fill: Color, stroke: Color, text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(stroke, lineWidth: 1))
                .frame(width: 14, height: 14)
            Text(text)
                .font(Typo.font(12, .regular, relativeTo: .caption))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

struct ReformerTile: View {
    let station: Station
    let state: ReformerTileState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ReformerIcon()
                    .stroke(iconColor, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 40, height: 20)
                Text("\(station.number)")
                    .font(Typo.font(20, state == .selected || state == .mine ? .medium : .light, relativeTo: .title3))
                    .monospacedDigit()
                    .foregroundStyle(numberColor)
                    .strikethrough(state == .taken || state == .outOfService, color: Theme.secondaryText.opacity(0.6))
                if state == .mine {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.onPink)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(background)
            .overlay(border)
            .scaleEffect(state == .selected ? 1.02 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state)
        }
        .buttonStyle(PressableCardStyle())
        .disabled(!isInteractive)
        .accessibilityLabel("Reformer \(station.number), \(accessibilityState)")
        .accessibilityAddTraits(state == .selected || state == .mine ? .isSelected : [])
    }

    private var isInteractive: Bool {
        state == .available || state == .selected
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }

    @ViewBuilder
    private var background: some View {
        switch state {
        case .selected, .mine: shape.fill(Theme.pink)
        case .taken, .outOfService: shape.fill(Theme.taken)
        case .available, .locked: shape.fill(Theme.card)
        }
    }

    @ViewBuilder
    private var border: some View {
        switch state {
        case .available, .locked: shape.strokeBorder(Theme.hairline, lineWidth: 1)
        default: EmptyView()
        }
    }

    private var iconColor: Color {
        switch state {
        case .selected, .mine: Theme.onPink
        case .taken, .outOfService: Theme.secondaryText.opacity(0.4)
        case .available, .locked: Theme.secondaryText
        }
    }

    private var numberColor: Color {
        switch state {
        case .selected, .mine: Theme.onPink
        case .taken, .outOfService: Theme.secondaryText.opacity(0.6)
        case .available, .locked: Theme.ink
        }
    }

    private var accessibilityState: String {
        switch state {
        case .available: "available"
        case .selected: "selected"
        case .taken: "taken"
        case .mine: "your reformer"
        case .outOfService: "out of service"
        case .locked: "not bookable"
        }
    }
}
