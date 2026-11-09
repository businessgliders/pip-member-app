import SwiftUI

/// Six rounded boxes over one hidden one-time-code field, so iOS can fill the code from
/// Messages or Mail and the member can paste it.
struct CodeBoxes: View {
    @Binding var code: String
    var focus: FocusState<Bool>.Binding
    /// Bump to shake (wrong code).
    let shakes: Int
    var onComplete: () -> Void

    @Environment(\.calmMotion) private var calm
    @State private var shakeAmount: CGFloat = 0

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .focused(focus)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(maxWidth: .infinity, minHeight: 64)
                .opacity(0.02)
                .accessibilityLabel("Six-digit code")
                .onChange(of: code) { _, new in
                    let digits = String(new.filter { $0.isASCII && $0.isNumber }.prefix(6))
                    if digits != new { code = digits; return }
                    if digits.count == 6 { onComplete() }
                }

            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    box(index)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture { focus.wrappedValue = true }
        .modifier(ShakeEffect(travel: shakeAmount))
        .onChange(of: shakes) { _, _ in
            guard !calm else { return }
            shakeAmount = 0
            withAnimation(Motion.codeShake) { shakeAmount = 1 }
        }
        .sensoryFeedback(.error, trigger: shakes)
    }

    private func box(_ index: Int) -> some View {
        let characters = Array(code)
        let digit = index < characters.count ? String(characters[index]) : ""
        let isCurrent = focus.wrappedValue && index == min(characters.count, 5)
        return Text(digit)
            .font(Typo.font(28, .medium, relativeTo: .title))
            .monospacedDigit()
            .foregroundStyle(Theme.cream)
            .frame(maxWidth: 56)
            .frame(height: 64)
            .frame(maxWidth: .infinity)
            .background(Theme.cream.opacity(digit.isEmpty ? 0.08 : 0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.cream.opacity(isCurrent ? 0.75 : 0.18), lineWidth: isCurrent ? 1.5 : 1)
            }
            .animation(Motion.fade, value: isCurrent)
            .animation(Motion.fade, value: digit)
    }
}

/// A gentle side-to-side shake: three damped swings over the animation.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat
    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = 8 * sin(travel * .pi * 6) * (1 - travel)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}
