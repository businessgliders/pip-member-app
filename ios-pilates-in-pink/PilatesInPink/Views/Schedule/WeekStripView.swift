import SwiftUI

struct WeekStripView: View {
    let vm: ScheduleViewModel
    @State private var direction: Int = 0

    var body: some View {
        HStack(spacing: 2) {
            arrow(systemName: "chevron.left", enabled: vm.canGoBack, label: "Previous week") { shift(-1) }

            HStack(spacing: 0) {
                ForEach(vm.days, id: \.self) { day in
                    dayCell(day)
                }
            }
            .id(vm.weekStart)
            .transition(.asymmetric(
                insertion: .move(edge: direction >= 0 ? .trailing : .leading).combined(with: .opacity),
                removal: .opacity
            ))

            arrow(systemName: "chevron.right", enabled: vm.canGoForward, label: "Next week") { shift(1) }
        }
        .clipped()
        .animation(Theme.spring, value: vm.weekStart)
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    if value.translation.width < -50 { shift(1) }
                    if value.translation.width > 50 { shift(-1) }
                }
        )
    }

    private func shift(_ delta: Int) {
        guard delta < 0 ? vm.canGoBack : vm.canGoForward else { return }
        direction = delta
        Task { await vm.shiftWeek(by: delta) }
    }

    private func arrow(systemName: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .background(Theme.card, in: Circle())
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(PressableCardStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = StudioTime.isSameDay(day, vm.selectedDay)
        let isToday = StudioTime.isSameDay(day, vm.today)
        let isEnabled = vm.isSelectable(day)

        return Button {
            withAnimation(Theme.spring) { vm.select(day) }
        } label: {
            VStack(spacing: 6) {
                Text(StudioTime.format(day, "EEEEE"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                Text(StudioTime.format(day, "d"))
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Theme.onPink : Theme.ink)
                    .frame(width: 38, height: 38)
                    .background {
                        if isSelected {
                            Circle()
                                .fill(Theme.pink)
                                .shadow(color: Theme.pink.opacity(0.45), radius: 8, x: 0, y: 4)
                        }
                    }
                Circle()
                    .fill(isToday ? Theme.caramel : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(StudioTime.format(day, "EEEE, MMMM d") + (isToday ? ", today" : ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
