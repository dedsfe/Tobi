import Foundation
import SwiftData

/// A nota de um dia: o texto livre que a pessoa escreveu, uma comida por linha.
@Model
final class DayNote {
    var day: Date = Date.now
    var text: String = ""

    init(day: Date, text: String = "") {
        self.day = Calendar.current.startOfDay(for: day)
        self.text = text
    }
}
