import SwiftUI

/// Line drawing of a reformer seen from the side: carriage, rail, legs and foot bar.
struct ReformerIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY
        var p = Path()

        // Rail
        p.move(to: CGPoint(x: x + 0.04 * w, y: y + 0.62 * h))
        p.addLine(to: CGPoint(x: x + 0.96 * w, y: y + 0.62 * h))

        // Carriage
        p.addRoundedRect(
            in: CGRect(x: x + 0.14 * w, y: y + 0.40 * h, width: 0.44 * w, height: 0.16 * h),
            cornerSize: CGSize(width: 0.05 * h, height: 0.05 * h)
        )

        // Headrest
        p.move(to: CGPoint(x: x + 0.06 * w, y: y + 0.62 * h))
        p.addLine(to: CGPoint(x: x + 0.06 * w, y: y + 0.44 * h))
        p.addLine(to: CGPoint(x: x + 0.12 * w, y: y + 0.44 * h))

        // Legs
        p.move(to: CGPoint(x: x + 0.10 * w, y: y + 0.62 * h))
        p.addLine(to: CGPoint(x: x + 0.10 * w, y: y + 0.88 * h))
        p.move(to: CGPoint(x: x + 0.90 * w, y: y + 0.62 * h))
        p.addLine(to: CGPoint(x: x + 0.90 * w, y: y + 0.88 * h))

        // Foot bar
        p.move(to: CGPoint(x: x + 0.80 * w, y: y + 0.62 * h))
        p.addLine(to: CGPoint(x: x + 0.88 * w, y: y + 0.14 * h))
        p.addLine(to: CGPoint(x: x + 0.97 * w, y: y + 0.14 * h))

        return p
    }
}
