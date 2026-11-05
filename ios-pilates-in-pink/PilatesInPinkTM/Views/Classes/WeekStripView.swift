import SwiftUI

/// Centered month title + S–S week strip. Swipe or tap arrows to change week.
struct WeekStripView: View {
    let vm: ScheduleViewModel
    @State private var direction: Int = 0

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                arrow("chevron.left", enabled: vm.canGoBack, label: "Previous week") { shift(-1) }
                Spacer()
                Text(vm.monthTitle)
                    .font(Typo.font(28, .light, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .animation(Theme.spring, value: vm.monthTitle)
                Spacer()
                arrow("chevron.right", enabled: vm.canGoForward, label: "Next week") { shift(1) }
            }

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
        }
        .clipped()
        .animation(Theme.spring, value: vm.weekStart)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < -50 { shift(1) }
                    if value.translation.width > 50 { shift(-1) }
                }
        )
        .sensoryFeedback(.selection, trigger: vm.selectedDay)
    }

    private func shift(_ delta: Int) {
        guard delta < 0 ? vm.canGoBack : vm.canGoForward else { return }
        direction = delta
        Task { await vm.shiftWeek(by: delta) }
    }

    private func arrow(_ systemName: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.2)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = StudioTime.isSameDay(day, vm.selectedDay)
        let isToday = StudioTime.isSameDay(day, vm.today)
        let selectable = vm.isSelectable(day)

        return Button {
            withAnimation(Theme.spring) { vm.select(day) }
        } label: {
            VStack(spacing: 8) {
                Text(String(StudioTime.format(day, "EEEEE")))
                    .font(Typo.font(12, .medium, relativeTo: .caption))
                    .tracking(1)
                    .foregroundStyle(Theme.secondaryText)
                Text(StudioTime.format(day, "d"))
                    .font(Typo.font(17, isSelected ? .medium : .regular, relativeTo: .body))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Theme.onPink : Theme.ink)
                    .frame(width: 40, height: 40)
                    .background {
                        if isSelected {
                            Circle().fill(Theme.pink)
                        }
                    }
                Circle()
                    .fill(isToday ? Theme.ink : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .opacity(selectable ? 1 : 0.3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
        .accessibilityLabel(StudioTime.format(day, "EEEE, MMMM d") + (isToday ? ", today" : ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
