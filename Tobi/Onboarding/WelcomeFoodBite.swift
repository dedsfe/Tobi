import Foundation

/// Reusa a pose de comer, sincronizada à chegada do emoji na boca.
enum WelcomeFoodBite {
    static let finish = 0.95

    /// O relógio do laboratório tem atraso de 0,35 s e velocidade de 1,7x.
    static func sequenceTime(elapsed: Double, flight: Double) -> Double {
        (age(elapsed: elapsed, flight: flight) + 0.35) / 1.7
    }

    static func age(elapsed: Double, flight: Double) -> Double {
        let elapsed = max(0, elapsed)
        let flight = max(0.01, flight)
        func ease(_ value: Double) -> Double {
            let t = min(1, max(0, value))
            return t * t * (3 - 2 * t)
        }
        if elapsed < flight * 0.6 {
            return 2.2 * ease(elapsed / (flight * 0.6))
        }
        if elapsed < flight * 0.85 {
            // Recolhe a língua antes de abrir a boca.
            return 2.2 + 0.7 * ease((elapsed / flight - 0.6) / 0.25)
        }
        if elapsed < flight {
            return 2.9 + 0.42 * ease((elapsed / flight - 0.85) / 0.15)
        }
        let after = elapsed - flight
        if after < 0.12 {
            return 3.32 + 0.2 * ease(after / 0.12)
        }
        if after < 0.68 {
            // Duas mastigadas; a língua permanece recolhida.
            let phase = (after - 0.12) / 0.56 * 4 * Double.pi
            return 3.52 - 0.2 * (1 - cos(phase)) / 2
        }
        // Termina contente e devolve a pose ao comportamento normal.
        return 3.52 + 0.53 * ease((after - 0.68) / (finish - 0.68))
    }
}
