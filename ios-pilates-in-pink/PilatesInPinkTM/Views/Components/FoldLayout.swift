import SwiftUI

/// Where the iPhone Duo fold (and any camera) sits inside a view, in that view's own coordinates.
/// On SDKs or devices without reserved regions this stays empty and every layout uses its fallback.
nonisolated struct FoldInfo: Equatable, Sendable {
    var width: CGFloat = 0
    /// Horizontal extent of a vertical fold that runs through the view.
    var fold: ClosedRange<CGFloat>?
    /// Frames of active camera cut-outs that cover the view.
    var occlusions: [CGRect] = []

    /// A fold with at least `margin` points of usable space on each side.
    func verticalFold(margin: CGFloat = 160) -> ClosedRange<CGFloat>? {
        guard let fold, fold.lowerBound >= margin, width - fold.upperBound >= margin else { return nil }
        return fold
    }

    static func read(_ proxy: GeometryProxy) -> FoldInfo {
        var info = FoldInfo(width: proxy.size.width)
#if canImport(SwiftUI, _version: 8.0.85)
        if #available(iOS 27.1, *) {
            // Include the inactive (flat) fold so layouts stay put while the hinge moves.
            let division = proxy.reservedRegions(kind: .division, options: .includeInactive)
                .first { $0.frame.height > $0.frame.width }
            if let frame = division?.frame,
               frame.maxX > 0, frame.minX < proxy.size.width {
                info.fold = frame.minX...frame.maxX
            }
            info.occlusions = proxy.reservedRegions(kind: .occlusion)
                .filter { $0.isActive }
                .map { $0.frame }
        }
#endif
        return info
    }
}

extension View {
    /// Keeps `info` up to date with this view's fold and camera regions.
    func readFold(into info: Binding<FoldInfo>) -> some View {
        onGeometryChange(for: FoldInfo.self) { proxy in
            FoldInfo.read(proxy)
        } action: { newValue in
            info.wrappedValue = newValue
        }
    }

    /// Moves single-column content to the roomier side of the fold, so nothing sits on it.
    func avoidingFold(gutter: CGFloat = 20) -> some View {
        modifier(AvoidFoldModifier(gutter: gutter))
    }
}

private struct AvoidFoldModifier: ViewModifier {
    let gutter: CGFloat
    @State private var info = FoldInfo()

    private var insets: (leading: CGFloat, trailing: CGFloat) {
        guard let fold = info.fold else { return (0, 0) }
        let leftRoom = fold.lowerBound
        let rightRoom = info.width - fold.upperBound
        if leftRoom >= rightRoom {
            return (0, max(0, info.width - fold.lowerBound + gutter))
        }
        return (max(0, fold.upperBound + gutter), 0)
    }

    func body(content: Content) -> some View {
        content
            .padding(.leading, insets.leading)
            .padding(.trailing, insets.trailing)
            .frame(maxWidth: .infinity)
            .readFold(into: $info)
    }
}

/// Passes the fold position of a full-width container to its content.
struct FoldReader<Content: View>: View {
    @ViewBuilder var content: (FoldInfo) -> Content
    @State private var info = FoldInfo()

    var body: some View {
        content(info)
            .frame(maxWidth: .infinity, alignment: .leading)
            .readFold(into: $info)
    }
}

/// Two columns. With a fold, the gap between them sits exactly on the fold;
/// otherwise they share the width equally.
struct FoldColumns<Leading: View, Trailing: View>: View {
    var spacing: CGFloat = 24
    var gutter: CGFloat = 18
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        FoldReader { info in
            if let fold = info.verticalFold() {
                HStack(alignment: .top, spacing: 0) {
                    leading
                        .frame(width: max(0, fold.lowerBound - gutter), alignment: .top)
                    Color.clear
                        .frame(width: fold.upperBound - fold.lowerBound + gutter * 2, height: 1)
                        .accessibilityHidden(true)
                    trailing
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            } else {
                HStack(alignment: .top, spacing: spacing) {
                    leading.frame(maxWidth: .infinity, alignment: .top)
                    trailing.frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
    }
}
