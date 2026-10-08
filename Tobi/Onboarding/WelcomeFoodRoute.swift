import Foundation
import CoreGraphics

/// A trajetória é independente do renderer e termina exatamente na boca projetada.
enum WelcomeFoodRoute {
    /// Quatro curvas: sobe pelo lado, cruza atrás, emerge e alcança a boca móvel.
    static func point(from start: CGPoint, to mouth: CGPoint, head: CGRect,
                      margin: CGFloat, at t: Double) -> CGPoint {
        let side: CGFloat = start.x < head.midX ? -1 : 1
        let points = [start, start,
                      CGPoint(x: head.midX + side * (head.width / 2 + margin), y: head.midY),
                      CGPoint(x: head.midX, y: head.midY - head.height * 0.15),
                      CGPoint(x: head.midX - side * (head.width / 2 + margin), y: head.midY),
                      mouth, mouth]
        let scaled = min(max(t, 0), 1) * 4
        let index = min(3, Int(scaled))
        let local = CGFloat(scaled - Double(index))
        let p0 = points[index], p1 = points[index + 1], p2 = points[index + 2], p3 = points[index + 3]
        func blend(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) -> CGFloat {
            0.5 * (2 * b + (-a + c) * local + (2 * a - 5 * b + 4 * c - d) * local * local
                   + (-a + 3 * b - 3 * c + d) * local * local * local)
        }
        return CGPoint(x: blend(p0.x, p1.x, p2.x, p3.x), y: blend(p0.y, p1.y, p2.y, p3.y))
    }
}
