import Foundation
import Testing
@testable import Tobi

struct TobiFaceAssetTests {
    @Test func bundledSculptureHasCompleteUsableMeshes() throws {
        let url = try #require(Bundle.main.url(forResource: "tobi-face", withExtension: "json"))
        let asset = try JSONDecoder().decode(TobiFaceAsset.self, from: Data(contentsOf: url))
        let names = Set(asset.parts.map(\.name))
        #expect(names.isSuperset(of: ["Head", "EyePatch", "EarLeft", "EarRight", "EyeLeft", "EyeRight", "Nose", "Mouth", "Tongue"]))
        for part in asset.parts {
            #expect(!part.vertices.isEmpty)
            #expect(part.normals.count == part.vertices.count)
            #expect(part.triangles.count % 3 == 0)
            #expect(part.triangles.allSatisfy { $0 < part.vertices.count })
            #expect(part.vertices.allSatisfy { $0.count == 3 && $0.allSatisfy(\.isFinite) })
            #expect(part.normals.allSatisfy { $0.count == 3 && $0.allSatisfy(\.isFinite) })
        }
        let left = try #require(asset.parts.first { $0.name == "EyeLeft" }?.position)
        let right = try #require(asset.parts.first { $0.name == "EyeRight" }?.position)
        #expect(left[0] < 0 && right[0] > 0)
        #expect(abs(left[0]) == abs(right[0]))
        #expect(left[1] == right[1])
        let tongue = try #require(asset.parts.first { $0.name == "Tongue" })
        let hinge = try #require(tongue.position)
        #expect(abs(hinge[1] + 0.512) < 0.0001)
        #expect(tongue.vertices.filter { $0[1] < 0 }.count > tongue.vertices.count / 2)
        for name in ["EarLeft", "EarRight"] {
            let ear = try #require(asset.parts.first { $0.name == name })
            let pivot = try #require(ear.position)
            #expect(pivot[1] > 0.6)
            #expect(ear.vertices.filter { $0[1] < 0 }.count > ear.vertices.count / 2)
        }
    }

    @Test func posablePartsKeepTheirTopologyInEveryPose() throws {
        let url = try #require(Bundle.main.url(forResource: "tobi-face", withExtension: "json"))
        let asset = try JSONDecoder().decode(TobiFaceAsset.self, from: Data(contentsOf: url))
        let expected = ["Mouth": ["open"], "MouthTongue": ["open"], "Tongue": ["curl"],
                        "EarLeft": ["bend"], "EarRight": ["bend"]]
        for (name, channels) in expected {
            let part = try #require(asset.parts.first { $0.name == name })
            let morphs = try #require(part.morphs)
            #expect(morphs.map(\.name) == channels)
            for morph in morphs {
                #expect(morph.poses.count >= 5 && morph.normals.count == morph.poses.count)
                #expect(morph.range.count == 2 && morph.range[0] < morph.range[1] && (morph.range[0]...morph.range[1]).contains(0))
                #expect(morph.poses.allSatisfy { $0.count == part.vertices.count && $0.allSatisfy { $0.count == 3 && $0.allSatisfy(\.isFinite) } })
            }
        }
        func height(_ pose: [[Float]]) -> Float { (pose.map { $0[1] }.max() ?? 0) - (pose.map { $0[1] }.min() ?? 0) }
        func top(_ pose: [[Float]]) -> Float { pose.map { $0[1] }.max() ?? 0 }
        let mouth = try #require(asset.parts.first { $0.name == "Mouth" }?.morphs?.first?.poses)
        let inner = try #require(asset.parts.first { $0.name == "MouthTongue" }?.morphs?.first?.poses)
        // Closed: a thin smile and no visible inside. Open: a real yawn.
        #expect(height(mouth[0]) < 0.06 && height(mouth[mouth.count-1]) > 0.12)
        #expect(height(inner[0]) < 0.06 && height(inner[inner.count-1]) > 0.04)
    }

    @MainActor @Test func threePetsProlongHappinessWithoutTurningTheHead() {
        var idle = TobiIdleBehavior(seed: 42)
        var control = TobiIdleBehavior(seed: 42)
        idle.spontaneous = false; control.spontaneous = false
        idle.setMood(.joyful, at: 0, entering: false)
        control.setMood(.joyful, at: 0, entering: false)
        _ = idle.sample(at: 0); _ = control.sample(at: 0)
        var singleHappy: Float = 0, thirdHappy: Float = 0
        for frame in 1..<720 {
            let t = Double(frame)/120
            if [60,240,420].contains(frame) { idle.pet(at: t) }
            let pose = idle.sample(at: t), baseline = control.sample(at: t)
            #expect(abs(pose.headYaw-baseline.headYaw) < 0.01)
            #expect(pose.cheer <= 0.85)
            if frame == 230 { singleHappy = pose.cheer }
            if frame == 590 { thirdHappy = pose.cheer }
        }
        #expect(thirdHappy > singleHappy + 0.3)
    }

    @MainActor @Test func independentIdleStaysBoundedAndSettlesBetweenGestures() {
        var idle = TobiIdleBehavior(seed: 42)
        // The face starts in its resting pose, not at zero.
        var previous = idle.sample(at: 0)
        var tongueCalmFrames = 0
        var tongueFrozenRun = 0
        var longestFrozen = 0
        var separateEarFrames = 0
        var blinkingFrames = 0
        var gazeHeldFrames = 0
        var pantingFrames = 0
        for frame in 1..<14400 {
            let pose = idle.sample(at: Double(frame)/120)
            let values = [pose.breath, pose.blink, pose.gazeX, pose.gazeY,
                          pose.headYaw, pose.headRoll, pose.leftEar, pose.rightEar,
                          pose.tonguePitch, pose.tongueStretch]
            #expect(values.allSatisfy { $0.isFinite })
            #expect((0...1).contains(pose.blink))
            #expect(abs(pose.gazeX) <= 0.03 && abs(pose.gazeY) <= 0.01)
            #expect((-0.32...0.1).contains(pose.leftEar) && (-0.1...0.32).contains(pose.rightEar))
            #expect(abs(pose.tonguePitch) <= 0.13 && (0.5...1.25).contains(pose.tongueStretch))
            #expect(abs(pose.tongueSway) <= 0.3 && (0...1).contains(pose.mouthOpen))
            #expect((0...1).contains(pose.tongueCurl) && (0...1).contains(pose.tongueRetract))
            #expect(abs(pose.leftEarBend) <= 0.6 && abs(pose.rightEarBend) <= 0.6)
            #expect(abs(pose.lift) < 0.05 && abs(pose.breath) <= 1)
            // Bound transitions as well as poses, including a gesture's start/end.
            #expect(abs(pose.leftEar-previous.leftEar) < 0.015)
            #expect(abs(pose.rightEar-previous.rightEar) < 0.015)
            #expect(abs(pose.tonguePitch-previous.tonguePitch) < 0.015)
            #expect(abs(pose.gazeX-previous.gazeX) < 0.004)
            if pose.tongueStretch > 1.1 { pantingFrames += 1 }
            if pose.tongueStretch < 1.06 { tongueCalmFrames += 1 }
            let still = abs(pose.tongueStretch-previous.tongueStretch) < 0.00001
                && abs(pose.tongueSway-previous.tongueSway) < 0.00001
            tongueFrozenRun = still ? tongueFrozenRun + 1 : 0
            longestFrozen = max(longestFrozen, tongueFrozenRun)
            if abs(pose.leftEar+pose.rightEar) > 0.02 { separateEarFrames += 1 }
            if pose.blink > 0.9 { blinkingFrames += 1 }
            if abs(pose.gazeX) > 0.015 && abs(pose.gazeX-previous.gazeX) < 0.00001 {
                gazeHeldFrames += 1
            }
            previous = pose
        }
        #expect(separateEarFrames > 0 && blinkingFrames > 0 && gazeHeldFrames > 0)
        // A happy dog pants a good share of the time, with calm breaths in between.
        #expect(pantingFrames > 14400/4 && tongueCalmFrames > 14400/10)
        // The tongue is never a frozen sticker, not even for a quarter of a second.
        #expect(longestFrozen < 30)
    }

    @MainActor @Test func idleCanBeReplayedWithoutSynchronizingEveryPart() {
        var first = TobiIdleBehavior(seed: 42)
        var replay = TobiIdleBehavior(seed: 42)
        var other = TobiIdleBehavior(seed: 71)
        var diverged = false
        for frame in 0..<3600 {
            let time = Double(frame)/60
            let a = first.sample(at: time), b = replay.sample(at: time), c = other.sample(at: time)
            #expect(a.leftEar == b.leftEar && a.rightEar == b.rightEar)
            #expect(a.tonguePitch == b.tonguePitch && a.blink == b.blink)
            if a.leftEar != c.leftEar || a.tonguePitch != c.tonguePitch { diverged = true }
        }
        #expect(diverged)
        #expect(TobiIdleBehavior.blinkClosure(age: -1) == 0)
        #expect(TobiIdleBehavior.blinkClosure(age: 1) == 0)
    }

    // MARK: - Estados do onboarding

    private static func channels(_ pose: TobiIdleBehavior.Pose) -> [Float] {
        [pose.gazeX, pose.gazeY, pose.headYaw, pose.headRoll, pose.headPitch, pose.lift,
         pose.leftEar, pose.rightEar, pose.tonguePitch, pose.tongueStretch, pose.cheer]
    }

    /// Mouth, curl and retract are quick by nature (a lick is fast), but never a cut.
    private static func expectSoftFace(_ pose: TobiIdleBehavior.Pose, after previous: TobiIdleBehavior.Pose) {
        #expect(abs(pose.mouthOpen-previous.mouthOpen) < 0.04)
        #expect(abs(pose.tongueCurl-previous.tongueCurl) < 0.06)
        #expect(abs(pose.tongueRetract-previous.tongueRetract) < 0.04)
        #expect(abs(pose.leftEarBend-previous.leftEarBend) < 0.03 && abs(pose.rightEarBend-previous.rightEarBend) < 0.03)
        #expect(abs(pose.eyeWiden-previous.eyeWiden) < 0.04)
    }

    @MainActor @Test func moodChangesAndReactionsNeverJump() {
        var idle = TobiIdleBehavior(seed: 42)
        idle.setMood(.joyful, at: 0, entering: true)
        // The onboarding in fast-forward: forward, taps, going back, re-presenting, mid-gesture cuts.
        let script: [(Double, (inout TobiIdleBehavior, Double) -> Void)] = [
            (1.0, { $0.setMood(.attentive, at: $1, entering: true) }),
            (1.5, { $0.acknowledge(at: $1) }), (1.6, { $0.acknowledge(at: $1) }),
            (2.0, { $0.setMood(.attentive, at: $1, entering: true) }),
            (3.4, { $0.setMood(.curious, at: $1, entering: true) }),
            (4.1, { $0.acknowledge(at: $1) }),
            (4.3, { $0.setMood(.attentive, at: $1, entering: false) }),
            (6.0, { $0.setMood(.curious, at: $1, entering: true) }),
            (9.0, { $0.setMood(.celebrating, at: $1, entering: true) }),
            (9.6, { $0.setMood(.presenting, at: $1, entering: true) }),
            (12.0, { $0.setMood(.attentive, at: $1, entering: false) }),
            (13.0, { $0.setMood(.celebrating, at: $1, entering: true) }),
            (20.0, { $0.setMood(.joyful, at: $1, entering: true) }),
            (20.2, { $0.setMood(.presenting, at: $1, entering: true) }),
        ]
        var next = 0
        var previous = idle.sample(at: 0)
        for frame in 1..<(120*40) {
            let time = Double(frame)/120
            while next < script.count, script[next].0 <= time {
                script[next].1(&idle, time)
                next += 1
            }
            let pose = idle.sample(at: time)
            #expect(Self.channels(pose).allSatisfy { $0.isFinite })
            #expect((0...1).contains(pose.blink) && pose.cheer <= 0.85)
            #expect(abs(pose.gazeX) <= 0.03 && abs(pose.gazeY) <= 0.012)
            #expect(abs(pose.headRoll) < 0.42 && abs(pose.headYaw) < 0.2 && (-0.14...0.13).contains(pose.headPitch))
            #expect((-0.32...0.1).contains(pose.leftEar) && (-0.1...0.32).contains(pose.rightEar))
            #expect(abs(pose.tonguePitch) <= 0.13 && (0.5...1.3).contains(pose.tongueStretch))
            #expect(abs(pose.lift) < 0.08)
            for (value, last) in zip(Self.channels(pose), Self.channels(previous)) {
                #expect(abs(value-last) < 0.015)
            }
            #expect(abs(pose.tongueSway) <= 0.25 && abs(pose.tongueSway-previous.tongueSway) < 0.02)
            Self.expectSoftFace(pose, after: previous)
            previous = pose
        }
    }

    @MainActor @Test func celebrationHappensOnceThenPresents() {
        var party = TobiIdleBehavior(seed: 9)
        party.setMood(.celebrating, at: 0, entering: true)
        var partyCheer: Float = 0
        var tongueMoved = false
        for frame in 0..<(120*4) {
            let pose = party.sample(at: Double(frame)/120)
            partyCheer = max(partyCheer, pose.cheer)
            if pose.tonguePitch > 0.05 { tongueMoved = true }
        }
        #expect(party.mood == .presenting)
        #expect(tongueMoved)

        // Going back to the plan restores the presenting state without celebrating again.
        var back = TobiIdleBehavior(seed: 9)
        back.setMood(.celebrating, at: 0, entering: false)
        #expect(back.mood == .presenting)
        var backCheer: Float = 0
        for frame in 0..<(120*4) { backCheer = max(backCheer, back.sample(at: Double(frame)/120).cheer) }
        #expect(partyCheer > backCheer + 0.05)
    }

    @MainActor @Test func presentingGlancesAtTheCardAndReturns() {
        var idle = TobiIdleBehavior(seed: 3)
        idle.setMood(.presenting, at: 0, entering: true)
        var lowest: Float = 0
        var deepestNod: Float = 0
        for frame in 0..<(120*2) {
            let pose = idle.sample(at: Double(frame)/120)
            lowest = min(lowest, pose.gazeY)
            deepestNod = max(deepestNod, pose.headPitch)
        }
        #expect(lowest < -0.007 && deepestNod > 0.04)
        for frame in (120*3)..<(120*4) {
            // Back to center: only the panting nod remains.
            #expect(idle.sample(at: Double(frame)/120).headPitch < 0.025)
        }
    }

    @MainActor @Test func reactionsDoNotRestartTheOtherClocks() {
        var plain = TobiIdleBehavior(seed: 5)
        var tapped = TobiIdleBehavior(seed: 5)
        plain.setMood(.attentive, at: 0, entering: true)
        tapped.setMood(.attentive, at: 0, entering: true)
        for frame in 0..<(120*12) {
            let time = Double(frame)/120
            // Answering pants on purpose; the eyes and ears keep their own clocks.
            if frame == 120*2 { tapped.acknowledge(at: time) }
            if frame == 120*3 { tapped.pet(at: time) }
            // A redraw that re-sends the same state is a no-op for the clocks.
            if frame == 120*5 { tapped.setMood(.attentive, at: time, entering: false) }
            let a = plain.sample(at: time), b = tapped.sample(at: time)
            #expect(a.gazeX == b.gazeX && a.gazeY == b.gazeY)
            if time < 2 || time > 2.4 { #expect(a.blink == b.blink) }
        }
    }

    @MainActor @Test func pettingSquintsAndKeepsEveryPartAttached() {
        var idle = TobiIdleBehavior(seed: 21)
        idle.setMood(.attentive, at: 0, entering: false)
        var previous = idle.sample(at: 0)
        var happiest: Float = 0

        for frame in 1..<(120*6) {
            let time = Double(frame)/120
            // Fast repeated taps chain into one gesture instead of restarting it.
            if [120, 150, 170, 240].contains(frame) { idle.pet(at: time) }
            let pose = idle.sample(at: time)
            happiest = max(happiest, pose.cheer)
            #expect((-0.32...0.1).contains(pose.leftEar) && (-0.1...0.32).contains(pose.rightEar))
            #expect(abs(pose.headRoll) < 0.32 && abs(pose.lift) < 0.08 && pose.cheer <= 0.85)
            for (index, (value, last)) in zip(Self.channels(pose).dropLast(), Self.channels(previous).dropLast()).enumerated() {
                #expect(abs(value-last) < 0.015, "channel \(index) frame \(frame): \(last) -> \(value)")
            }
            #expect(abs(pose.cheer-previous.cheer) < 0.06)
            previous = pose
        }
        #expect(happiest > 0.5)
    }

    @MainActor @Test func followsTheFingerSmoothlyThenLetsGo() throws {
        var idle = TobiIdleBehavior(seed: 5)
        idle.setMood(.curious, at: 0, entering: false)
        var previous = idle.sample(at: 0)
        var lowerRight: TobiIdleBehavior.Pose?
        var upperLeft: TobiIdleBehavior.Pose?
        for frame in 1..<(120*8) {
            let time = Double(frame)/120
            // Taps down-right, then a drag up-left, then the finger leaves; pets mid-drag.
            switch frame {
            case 120..<240: idle.follow(SIMD2(0.6, -0.8), at: time)
            case 240..<540: idle.follow(SIMD2(-0.9 + 0.3*min(1,Float(frame-240)/120), 0.4), at: time)
            default: idle.follow(nil, at: time)
            }
            if frame == 300 { idle.pet(at: time) }
            let pose = idle.sample(at: time)
            if frame == 230 { lowerRight = pose }
            if frame == 530 { upperLeft = pose }
            #expect(abs(pose.gazeX) <= 0.03 && abs(pose.gazeY) <= 0.012)
            #expect(abs(pose.headYaw) <= 0.21 && (-0.08...0.2).contains(pose.headPitch))
            #expect((-0.32...0.1).contains(pose.leftEar) && (-0.1...0.32).contains(pose.rightEar))
            for (index, (value, last)) in zip(Self.channels(pose).dropLast(), Self.channels(previous).dropLast()).enumerated() {
                #expect(abs(value-last) < 0.015, "channel \(index) frame \(frame): \(last) -> \(value)")
            }
            previous = pose
        }
        let down = try #require(lowerRight), up = try #require(upperLeft)
        // Eyes and head track the finger again after the cute pet reaction finishes.
        #expect(down.gazeX > 0.012 && down.gazeY < -0.006 && down.headYaw > 0.08 && down.headPitch > 0.08)
        #expect(up.gazeX < -0.012 && up.gazeY > 0.002 && up.headYaw < -0.08 && up.headPitch < 0.02)
        // Seconds after letting go he is back to his own idle, facing forward.
        #expect(abs(previous.headYaw) < 0.11 && abs(previous.gazeX) < 0.03)
    }

    @MainActor @Test func draggingTurnsHimTowardThePull() {
        func yaw(swipe: Float) -> Float {
            var idle = TobiIdleBehavior(seed: 3)
            var pose = idle.sample(at: 0)
            for frame in 1...90 {
                let time = Double(frame)/120
                idle.follow(SIMD2(0, -0.8), swipe: swipe, at: time)
                pose = idle.sample(at: time)
            }
            return pose.headYaw
        }
        let still = yaw(swipe: 0)
        #expect(yaw(swipe: 2) > still + 0.1)
        #expect(yaw(swipe: -2) < still - 0.1)

        // A pull back and forth never snaps the head, and letting go swings him back.
        var idle = TobiIdleBehavior(seed: 3)
        var previous = idle.sample(at: 0)
        for frame in 1..<(120*5) {
            let time = Double(frame)/120
            let pull: Float = frame < 120 ? 3 : frame < 240 ? -3 : 0
            idle.follow(frame < 240 ? SIMD2(0, -0.8) : nil, swipe: pull, at: time)
            let pose = idle.sample(at: time)
            #expect(abs(pose.headYaw) < 0.45 && abs(pose.headYaw-previous.headYaw) < 0.02)
            #expect(abs(pose.tongueSway) <= 0.3 && abs(pose.tongueSway-previous.tongueSway) < 0.02)
            previous = pose
        }
        #expect(abs(previous.headYaw) < 0.11)
    }

    @MainActor @Test func quirksAllShowUpAndNeverJump() {
        var idle = TobiIdleBehavior(seed: 8)
        var seen = Set<String>()
        var widestYawn: Float = 0
        var widestTurn: Float = 0
        var previous = idle.sample(at: 0)
        for frame in 1..<(120*240) {
            let time = Double(frame)/120
            let pose = idle.sample(at: time)
            if let quirk = idle.quirk { seen.insert("\(quirk)") }
            if idle.quirk == .yawn { widestYawn = max(widestYawn, pose.mouthOpen) }
            if idle.quirk == .distraction { widestTurn = max(widestTurn, abs(pose.headYaw)) }
            if idle.quirk == nil { #expect(pose.mouthOpen <= 0.45) }
            #expect(pose.cheer <= 0.85)
            for (index, (value, last)) in zip(Self.channels(pose), Self.channels(previous)).enumerated() {
                #expect(abs(value-last) < 0.015, "channel \(index) frame \(frame): \(last) -> \(value)")
            }
            #expect(abs(pose.tongueSway-previous.tongueSway) < 0.02)
            Self.expectSoftFace(pose, after: previous)
            previous = pose
        }
        #expect(seen == Set(TobiIdleBehavior.Quirk.allCases.map { "\($0)" }))
        #expect(widestYawn > 0.9 && widestTurn > 0.1)
    }

    @MainActor @Test func quirksWaitWhileSomeoneIsTouching() {
        var idle = TobiIdleBehavior(seed: 8)
        for frame in 0..<(120*60) {
            let time = Double(frame)/120
            idle.follow(SIMD2(0.2, -0.5), at: time)
            _ = idle.sample(at: time)
            #expect(idle.quirk == nil)
        }
    }

    @MainActor @Test func everyMoodHasAVisibleStillExpression() {
        for mood in TobiIdleBehavior.Mood.allCases {
            let pose = TobiIdleBehavior.still(mood)
            #expect(pose.blink == 0 && (0...0.3).contains(pose.cheer))
            #expect(abs(pose.headRoll) < 0.3 && (-0.05...0).contains(pose.headPitch) && pose.lift == 0)
            #expect(pose.mouthOpen == 0 && pose.tongueRetract == 0)
        }
    }

    /// The states must read apart at a glance, not only in numbers.
    @MainActor @Test func moodsLookClearlyDifferent() {
        struct Summary {
            var tongue: Float = 0, cheer: Float = 0, perk: Float = 0, widen: Float = 0
            var lowestRoll: Float = 0, highestRoll: Float = 0, glances = 0
        }
        func summary(_ mood: TobiIdleBehavior.Mood) -> Summary {
            var idle = TobiIdleBehavior(seed: 11)
            idle.setMood(mood, at: 0, entering: true)
            var out = Summary()
            var looking = false
            let frames = 120*30
            for frame in 0..<frames {
                let pose = idle.sample(at: Double(frame)/120)
                out.tongue += pose.tongueStretch; out.cheer += pose.cheer; out.widen += pose.eyeWiden
                out.perk += pose.rightEar - pose.leftEar
                out.lowestRoll = min(out.lowestRoll, pose.headRoll); out.highestRoll = max(out.highestRoll, pose.headRoll)
                // A glance at the card below: eyes down past the idle range.
                if pose.gazeY < -0.006, !looking { out.glances += 1 }
                looking = pose.gazeY < -0.006
            }
            let n = Float(frames)
            out.tongue /= n; out.cheer /= n; out.perk /= n; out.widen /= n
            return out
        }
        let joyful = summary(.joyful), attentive = summary(.attentive)
        let curious = summary(.curious), presenting = summary(.presenting)
        #expect(joyful.tongue > attentive.tongue + 0.15)
        #expect(joyful.cheer > attentive.cheer + 0.08)
        #expect(attentive.widen > 0.9 && joyful.widen < 0.1)
        // Curious tilts the head for real, to one side and then the other.
        #expect(curious.lowestRoll < -0.18 && curious.highestRoll > 0.18)
        // Presenting keeps showing the card instead of glancing once and freezing.
        #expect(presenting.glances >= 4)
    }

    @MainActor @Test func yawnHidesTheTongueBeforeOpeningAndSneezeSpraysOnce() {
        var idle = TobiIdleBehavior(seed: 2)
        idle.spontaneous = false
        _ = idle.sample(at: 0)
        idle.perform(.yawn, at: 0.5)
        var tongueInFirst = false, opened = false, licked = false
        for frame in 61..<(120*5) {
            let time = Double(frame)/120
            let pose = idle.sample(at: time)
            if pose.tongueRetract > 0.9 && pose.mouthOpen < 0.2 { tongueInFirst = true }
            if pose.mouthOpen > 0.95 { opened = true; #expect(pose.tongueRetract > 0.95) }
            if time > 3.5 && pose.tongueCurl > 0.5 { licked = true }
        }
        #expect(tongueInFirst && opened && licked)

        idle.perform(.sneeze, at: 6)
        for frame in (120*6)..<(120*9) { _ = idle.sample(at: Double(frame)/120) }
        #expect(idle.sneezes == 1)
        // Without spontaneous quirks nothing else happens on its own.
        for frame in (120*9)..<(120*60) { _ = idle.sample(at: Double(frame)/120); #expect(idle.quirk == nil) }
    }

    @Test func onboardingStepsUseTheProposedStates() {
        #expect(OnboardingStep.welcome.tobiMood == .joyful)
        for step in [OnboardingStep.sex, .birthday, .height, .weight, .pace] {
            #expect(step.tobiMood == .attentive)
        }
        #expect(OnboardingStep.objective.tobiMood == .curious && OnboardingStep.activity.tobiMood == .curious)
        #expect(OnboardingStep.goals.tobiMood == .presenting)
    }

    @Test func answeringMakesTobiHappyUntilTheNextQuestion() {
        var answers = OnboardingAnswers()
        #expect(OnboardingView.mood(for: .height, in: answers) == .attentive)
        answers.heightCm = 170
        #expect(OnboardingView.mood(for: .height, in: answers) == .joyful)
        #expect(OnboardingView.mood(for: .objective, in: answers) == .curious)
        // A goal that does not match the objective is not an answer yet: he stays gentle, not sad.
        answers.objective = .lose
        answers.weightKg = 70
        answers.goalWeightKg = 80
        #expect(OnboardingView.mood(for: .weight, in: answers) == .attentive)
        answers.goalWeightKg = 65
        #expect(OnboardingView.mood(for: .weight, in: answers) == .joyful)
    }
}
