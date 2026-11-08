import SwiftUI
import UIKit

/// The create-account password field. UIKit so iOS Passwords gets the studio's password rules
/// when it suggests a strong password; SwiftUI's SecureField can't carry them.
struct NewPasswordField: UIViewRepresentable {
    static let rules = "minlength: 8; required: lower; required: upper; required: digit;"

    @Binding var text: String
    @Binding var isFocused: Bool
    var revealed: Bool
    var placeholder: String = "Password"
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.textContentType = .newPassword
        field.passwordRules = UITextInputPasswordRules(descriptor: Self.rules)
        field.isSecureTextEntry = !revealed
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.returnKeyType = .join
        field.keyboardAppearance = .dark
        field.textColor = .white
        field.tintColor = .white
        let base = UIFont(name: "DMSans-Regular", size: 16) ?? .systemFont(ofSize: 16)
        field.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
        field.adjustsFontForContentSizeCategory = true
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.55), .font: field.font as Any]
        )
        field.accessibilityLabel = "New password"
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        if field.isSecureTextEntry == revealed {
            field.isSecureTextEntry = !revealed
            // Re-setting the text keeps it from clearing when secure entry turns back on.
            let current = field.text
            field.text = nil
            field.text = current
        }
        if isFocused, !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !isFocused, field.isFirstResponder {
            DispatchQueue.main.async { field.resignFirstResponder() }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NewPasswordField

        init(_ parent: NewPasswordField) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isFocused { parent.isFocused = false }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }
    }
}
