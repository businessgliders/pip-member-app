import SafariServices
import SwiftUI

/// An in-app Safari page (banner links, Terms, Privacy Policy).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(Theme.fixedInk)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Identifiable wrapper so a URL can drive `.sheet(item:)`.
struct SafariLink: Identifiable, Equatable {
    let url: URL
    var id: String { url.absoluteString }
}

extension View {
    func safariSheet(_ link: Binding<SafariLink?>) -> some View {
        sheet(item: link) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
    }
}
