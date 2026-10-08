import Foundation
import CoreGraphics
import Testing
@testable import Tobi

struct WelcomeFoodRouteTests {
    private let head = CGRect(x: 140, y: 28, width: 110, height: 130)
    private let mouth = CGPoint(x: 197, y: 132)

    @Test func landsOnMovingMouthFromEitherSide() {
        for x in [45.0, 120, 260, 350] {
            for dx in [-15.0, 0, 15] {
                for dy in [-12.0, 0, 12] {
                    let start = CGPoint(x: x, y: 390)
                    let target = CGPoint(x: mouth.x + dx, y: mouth.y + dy)
                    #expect(WelcomeFoodRoute.point(from: start, to: target, head: head, margin: 54, at: 0) == start)
                    #expect(WelcomeFoodRoute.point(from: start, to: target, head: head, margin: 54, at: 1) == target)
                }
            }
        }
    }

    @Test func layerChangesClearTheWholeEmoji() {
        for size in [36.0, 40, 44, 46, 58, 62] {
            for x in [45.0, 350] {
                let start = CGPoint(x: x, y: 390)
                let rising = WelcomeFoodRoute.point(from: start, to: mouth, head: head, margin: size * 0.9, at: 0.25)
                let emerging = WelcomeFoodRoute.point(from: start, to: mouth, head: head, margin: size * 0.9, at: 0.75)
                // Até o quadrado de desenho inteiro fica fora da cabeça na troca de camada.
                let radius = size * 0.75
                #expect(rising.x + radius < head.minX || rising.x - radius > head.maxX)
                #expect(emerging.x + radius < head.minX || emerging.x - radius > head.maxX)
                #expect((rising.x < head.midX) != (emerging.x < head.midX))
            }
        }
    }

    @Test func crossesInsideHeadWhileBehind() {
        for x in [45.0, 350] {
            let point = WelcomeFoodRoute.point(from: CGPoint(x: x, y: 390), to: mouth, head: head,
                                              margin: 54, at: 0.5)
            #expect(head.contains(point))
            #expect(abs(point.x - head.midX) < 0.001)
        }
    }

    @Test func hasNoJumpAtCurveJoins() {
        for x in [45.0, 350] {
            let start = CGPoint(x: x, y: 390)
            for t in [0.25, 0.5, 0.75] {
                let before = WelcomeFoodRoute.point(from: start, to: mouth, head: head, margin: 54, at: t - 0.00001)
                let after = WelcomeFoodRoute.point(from: start, to: mouth, head: head, margin: 54, at: t + 0.00001)
                #expect(hypot(before.x - after.x, before.y - after.y) < 0.1)
            }
        }
    }

    @Test func clampsTimeAndStaysFinite() {
        let start = CGPoint(x: 45, y: 390)
        #expect(WelcomeFoodRoute.point(from: start, to: mouth, head: head, margin: 54, at: -1) == start)
        #expect(WelcomeFoodRoute.point(from: start, to: mouth, head: head, margin: 54, at: 2) == mouth)
        for frame in 0...1000 {
            let point = WelcomeFoodRoute.point(from: start, to: mouth, head: head, margin: 54, at: Double(frame) / 1000)
            #expect(point.x.isFinite && point.y.isFinite)
        }
    }
}
