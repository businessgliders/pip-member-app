import SwiftUI

/// Mirrors the real room: instructor at the front, reformers placed by row/column.
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
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Theme.softPink).frame(width: 30, height: 30)
                    Image(systemName: "figure.pilates")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                Text("Front of room")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)

            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(columns, id: \.self) { column in
                        if let station = stations.first(where: { $0.row == row && $0.column == column }) {
                            ReformerTile(station: station, state: stateFor(station)) {
                                onTap(station)
                            }
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 72)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.card.opacity(0.7), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Theme.hairline.opacity(0.6), lineWidth: 1)
        )
    }
}

struct ReformerTile: View {
    let station: Station
    let state: ReformerTileState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ReformerIcon()
                    .stroke(iconColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 50, height: 25)
                Text("\(station.number)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(numberColor)
                if state == .mine {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.onPink)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(background)
            .overlay(border)
            .overlay {
                if state == .outOfService {
                    GeometryReader { geo in
                        Path { p in
                            p.move(to: CGPoint(x: 18, y: geo.size.height - 14))
                            p.addLine(to: CGPoint(x: geo.size.width - 18, y: 14))
                        }
                        .stroke(Theme.secondaryText.opacity(0.5), lineWidth: 1.5)
                    }
                }
            }
            .scaleEffect(state == .selected ? 1.03 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: state)
        }
        .buttonStyle(PressableCardStyle())
        .disabled(!isInteractive)
        .accessibilityLabel("Reformer \(station.number), \(accessibilityState)")
        .accessibilityAddTraits(state == .selected || state == .mine ? .isSelected : [])
    }

    private var isInteractive: Bool {
        state == .available || state == .selected
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        switch state {
        case .selected, .mine:
            shape.fill(Theme.pink).shadow(color: Theme.pink.opacity(0.4), radius: 10, x: 0, y: 5)
        case .taken, .outOfService:
            shape.fill(Theme.taken)
        case .available, .locked:
            shape.fill(Theme.card).shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private var border: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        switch state {
        case .available, .locked:
            shape.strokeBorder(Theme.hairline, lineWidth: 1)
        default:
            EmptyView()
        }
    }

    private var iconColor: Color {
        switch state {
        case .selected, .mine: Theme.onPink
        case .taken, .outOfService: Theme.secondaryText.opacity(0.5)
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
