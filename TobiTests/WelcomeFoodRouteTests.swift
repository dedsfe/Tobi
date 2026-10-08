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

struct WelcomeFoodBiteTests {
    @Test func retractsTongueAndOpensBeforeFoodEnters() {
        for flight in [1.0, 1.5, 2.0] {
            #expect(abs(WelcomeFoodBite.age(elapsed: flight * 0.6, flight: flight) - 2.2) < 0.00001)
            #expect(abs(WelcomeFoodBite.age(elapsed: flight * 0.85, flight: flight) - 2.9) < 0.00001)
            #expect(abs(WelcomeFoodBite.age(elapsed: flight, flight: flight) - 3.32) < 0.00001)
        }
    }

    @Test func chewsTwiceWithTongueStillRetracted() {
        let flight = 1.5
        for offset in [0.0, 0.28, 0.56] {
            #expect(abs(WelcomeFoodBite.age(elapsed: flight + 0.12 + offset, flight: flight) - 3.52) < 0.00001)
        }
        for offset in [0.14, 0.42] {
            #expect(abs(WelcomeFoodBite.age(elapsed: flight + 0.12 + offset, flight: flight) - 3.32) < 0.00001)
        }
    }

    @Test func completesWithoutStartingAnotherSnackCycle() {
        #expect(abs(WelcomeFoodBite.age(elapsed: 1.5 + WelcomeFoodBite.finish, flight: 1.5) - 4.05) < 0.00001)
        #expect(abs(WelcomeFoodBite.age(elapsed: 100, flight: 1.5) - 4.05) < 0.00001)
        #expect(WelcomeFoodBite.age(elapsed: -1, flight: 1.5) == 0)
    }

    @Test func joinsPreparationBiteAndChewingWithoutJumps() {
        for t in [0.9, 1.275, 1.5, 1.62, 2.18, 2.45] {
            let before = WelcomeFoodBite.age(elapsed: t - 0.00001, flight: 1.5)
            let after = WelcomeFoodBite.age(elapsed: t + 0.00001, flight: 1.5)
            #expect(abs(before - after) < 0.001)
        }
    }
}

#if canImport(Tobi)
@MainActor
struct WelcomeFoodEatingPoseTests {
    private func pose(at elapsed: Double) -> TobiIdleBehavior.Pose {
        TobiSnackSequence.pose(TobiIdleBehavior.Pose(),
                               at: WelcomeFoodBite.sequenceTime(elapsed: elapsed, flight: 1.5))
    }

    @Test func receivesFoodWithOpenMouthAndRetractedTongue() {
        for time in [1.275, 1.4, 1.5] {
            #expect(pose(at: time).mouthOpen > 0.85)
            #expect(pose(at: time).tongueRetract > 0.99)
        }
    }

    @Test func mouthChewsTwiceAfterArrival() {
        for time in [1.62, 1.9, 2.18] {
            #expect(pose(at: time).mouthOpen < 0.01)
            #expect(pose(at: time).tongueRetract > 0.99)
        }
        for time in [1.76, 2.04] {
            #expect(pose(at: time).mouthOpen > 0.85)
            #expect(pose(at: time).tongueRetract > 0.99)
        }
    }

    @Test func releasesTongueAfterFinishing() {
        #expect(pose(at: 1.5 + WelcomeFoodBite.finish).tongueRetract < 0.01)
        #expect(pose(at: 1.5 + WelcomeFoodBite.finish).mouthOpen < 0.01)
    }
}
#endif
