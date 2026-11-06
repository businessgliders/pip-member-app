import SwiftUI

/// Collapsible filter groups over the loaded schedule. Pure client-side filtering.
struct FiltersSheet: View {
    @Bindable var vm: ScheduleViewModel
    let resultCount: (ClassFilters) -> Int
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ClassFilters()
    @State private var expanded: Set<String> = ["Class"]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Filters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation(Theme.spring) { draft = ClassFilters() }
                        } label: {
                            Label("Clear", systemImage: "arrow.counterclockwise")
                        }
                        .disabled(draft.isEmpty)
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.sheetRadius)
        .presentationBackground(Theme.background)
        .sensoryFeedback(.selection, trigger: draft)
        .onAppear { draft = vm.filters }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    group("Class", options: vm.familyOptions.map { ($0.displayName, $0.rawValue) },
                          isOn: { raw in draft.families.contains(where: { $0.rawValue == raw }) },
                          toggle: { raw in
                              guard let f = ClassFamily(rawValue: raw) else { return }
                              draft.families.formSymmetricDifference([f])
                          })
                    group("Instructor", options: vm.instructorOptions.map { ($0, $0) },
                          isOn: { draft.instructors.contains($0) },
                          toggle: { draft.instructors.formSymmetricDifference([$0]) })
                    group("Level", options: vm.levelOptions.map { ($0, $0) },
                          isOn: { draft.levels.contains($0) },
                          toggle: { draft.levels.formSymmetricDifference([$0]) })
                    group("Time of Day", options: TimeOfDay.allCases.map { ($0.rawValue, $0.rawValue) },
                          isOn: { raw in draft.times.contains(where: { $0.rawValue == raw }) },
                          toggle: { raw in
                              guard let t = TimeOfDay(rawValue: raw) else { return }
                              draft.times.formSymmetricDifference([t])
                          })
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)

            Button {
                vm.filters = draft
                dismiss()
            } label: {
                let count = resultCount(draft)
                Text(draft.isEmpty ? "Show Classes" : "Show \(count) \(count == 1 ? "Class" : "Classes")")
                    .contentTransition(.numericText())
            }
            .buttonStyle(PillButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(Theme.background)
        .avoidingFold()
    }

    private func group(
        _ title: String,
        options: [(label: String, value: String)],
        isOn: @escaping (String) -> Bool,
        toggle: @escaping (String) -> Void
    ) -> some View {
        let isOpen = expanded.contains(title)
        let selectedCount = options.filter { isOn($0.value) }.count
        return VStack(spacing: 0) {
            Button {
                withAnimation(Theme.spring) { expanded.formSymmetricDifference([title]) }
            } label: {
                HStack {
                    EyebrowText(title, color: Theme.ink, size: 13)
                    if selectedCount > 0 {
                        Text("\(selectedCount)")
                            .font(Typo.font(12, .medium, relativeTo: .caption))
                            .foregroundStyle(Theme.onPink)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Theme.pink, in: Circle())
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Theme.ink)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .frame(minHeight: 60)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(spacing: 0) {
                    if options.isEmpty {
                        Text("Nothing to filter yet this week.")
                            .font(Typo.secondary)
                            .foregroundStyle(Theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 14)
                    }
                    ForEach(options, id: \.value) { option in
                        Button { toggle(option.value) } label: {
                            HStack {
                                Text(option.label)
                                    .font(Typo.body)
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                ZStack {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(isOn(option.value) ? Color.clear : Theme.hairline, lineWidth: 1.5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .fill(isOn(option.value) ? Theme.pink : Color.clear)
                                        )
                                    if isOn(option.value) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Theme.onPink)
                                    }
                                }
                                .frame(width: 24, height: 24)
                            }
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn(option.value) ? .isSelected : [])
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity)
            }
            Hairline()
        }
    }
}
