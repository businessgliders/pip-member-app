import SwiftUI

struct StudioInfoSheet: View {
    enum Section: String, Identifiable { case details, hours; var id: String { rawValue } }

    let initial: Section
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Spacer()
                    GlassCircleButton(systemImage: "xmark", label: "Close") { dismiss() }
                }
                StudioPhoto(name: "studio_brampton")
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                ScreenTitle(text: "\(StudioInfo.name)\n\(StudioInfo.city)", size: 30)

                if initial == .hours {
                    hours
                    details
                } else {
                    details
                    hours
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.sheetRadius)
        .presentationBackground(Theme.background)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowText("Details").padding(.bottom, 8)
            row("mappin.and.ellipse", StudioInfo.addressLines.joined(separator: "\n")) {
                if let url = StudioInfo.mapsURL { openURL(url) }
            }
            Hairline()
            row("phone", StudioInfo.phoneDisplay) {
                if let url = StudioInfo.phoneURL { openURL(url) }
            }
            Hairline()
            row("globe", "pilatesinpinkstudio.com") {
                if let url = StudioInfo.website { openURL(url) }
            }
        }
        .cardStyle(padding: 18)
    }

    private var hours: some View {
        let today = StudioTime.calendar.component(.weekday, from: Date())
        let order = [2, 3, 4, 5, 6, 7, 1]
        let names = [1: "Sunday", 2: "Monday", 3: "Tuesday", 4: "Wednesday", 5: "Thursday", 6: "Friday", 7: "Saturday"]
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                EyebrowText("Hours")
                Spacer()
                Text(StudioInfo.statusLine())
                    .font(Typo.font(13, .regular, relativeTo: .footnote))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.bottom, 8)
            ForEach(order, id: \.self) { day in
                HStack(alignment: .top) {
                    Text(names[day] ?? "")
                        .font(Typo.font(15, day == today ? .medium : .regular, relativeTo: .subheadline))
                    Spacer()
                    Text(StudioInfo.hoursText(weekday: day).replacingOccurrences(of: ", ", with: "\n"))
                        .font(Typo.font(15, day == today ? .medium : .regular, relativeTo: .subheadline))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 10)
                if day != 1 { Hairline() }
            }
        }
        .cardStyle(padding: 18)
    }

    private func row(_ icon: String, _ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .frame(width: 22)
                Text(text)
                    .font(Typo.body)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Theme.secondaryText)
            }
            .foregroundStyle(Theme.ink)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
    }
}
