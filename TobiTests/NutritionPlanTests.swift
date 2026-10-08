import Foundation
import Testing
@testable import Tobi

struct NutritionPlanTests {
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 7))!

    private func answers(sex: Sex, born year: Int, height: Int, weight: Double, goal: Double,
                         activity: ActivityLevel) -> OnboardingAnswers {
        let objective: Objective = goal < weight ? .lose : (goal > weight ? .gain : .maintain)
        var answers = OnboardingAnswers()
        answers.sex = sex
        answers.birthday = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))
        answers.heightCm = height
        answers.objective = objective
        answers.weightKg = weight
        answers.goalWeightKg = goal
        answers.activity = activity
        answers.pace = .recommended
        return answers
    }

    @Test func gainingWeightAddsToDailyBurn() throws {
        let plan = try #require(NutritionPlan(
            answers: answers(sex: .male, born: 2002, height: 178, weight: 70, goal: 80, activity: .moderate), now: now))
        // 10·70 + 6,25·178 − 5·24 + 5 = 1.697,5
        #expect(plan.restingKcal == 1698)
        #expect(plan.dailyBurnKcal == 2631)
        // Ganhar massa no ritmo recomendado: 0,25 kg por semana = +275 cal por dia.
        #expect(plan.goalAdjustment == 275)
        #expect(plan.kcal == 2910)
        // Ganhar massa: 2,0 g de proteína por kg.
        #expect(plan.proteinGrams == 140)
        #expect(plan.fatGrams == 81)
        #expect(plan.carbsGrams == 405)
    }

    @Test func losingWeightNeverGoesBelowMinimum() throws {
        let plan = try #require(NutritionPlan(
            answers: answers(sex: .female, born: 1966, height: 150, weight: 45, goal: 40,
                             activity: .sedentary), now: now))
        // 0,5 kg por semana passaria de 1% dos 45 kg: limita em 0,45 kg = −495 cal por dia.
        #expect(plan.goalAdjustment == -495)
        #expect(plan.kcal == NutritionPlan.minimumKcal)
    }

    @Test func preferNotToSayUsesAverageOfBothFormulas() throws {
        let male = try #require(NutritionPlan(
            answers: answers(sex: .male, born: 1990, height: 170, weight: 70, goal: 70, activity: .light), now: now))
        let female = try #require(NutritionPlan(
            answers: answers(sex: .female, born: 1990, height: 170, weight: 70, goal: 70, activity: .light), now: now))
        let neutral = try #require(NutritionPlan(
            answers: answers(sex: .undisclosed, born: 1990, height: 170, weight: 70, goal: 70, activity: .light), now: now))
        #expect(neutral.restingKcal == (male.restingKcal + female.restingKcal) / 2)
        #expect(neutral.goalAdjustment == 0)
    }

    @Test func maintainingKeepsRegularProtein() throws {
        let plan = try #require(NutritionPlan(
            answers: answers(sex: .male, born: 1995, height: 180, weight: 80, goal: 80, activity: .active), now: now))
        #expect(plan.goalAdjustment == 0)
        #expect(plan.proteinGrams == 128)
    }

    @Test func fasterPaceMeansBiggerDeficit() {
        let relaxed = NutritionPlan.weeklyRate(objective: .lose, pace: .relaxed, weightKg: 90)
        let fast = NutritionPlan.weeklyRate(objective: .lose, pace: .fast, weightKg: 90)
        #expect(relaxed == 0.25)
        #expect(fast == 0.75)
        #expect(NutritionPlan.weeklyRate(objective: .gain, pace: .fast, weightKg: 90) == 0.5)
    }

    @Test func customPaceFollowsTheChosenDateUpToTheLimit() {
        // Perder 10 kg em 10 semanas = 1 kg por semana.
        let tenWeeks = Calendar.current.date(byAdding: .day, value: 70, to: now)!
        let rate = NutritionPlan.weeklyRate(objective: .lose, pace: .custom, weightKg: 80, goalKg: 70,
                                            targetDate: tenWeeks, now: now)
        #expect(abs(rate - 1) < 0.001)
        // Perder 50 kg em 1 semana não passa do máximo: 1,5% de 200 kg = 3, teto de 2 kg.
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        let capped = NutritionPlan.weeklyRate(objective: .lose, pace: .custom, weightKg: 200, goalKg: 150,
                                              targetDate: nextWeek, now: now)
        #expect(capped == 2)
    }

    @Test func warningsGrowWithThePace() {
        #expect(PaceWarning(objective: .lose, rate: 0.7, weightKg: 80) == nil)
        #expect(PaceWarning(objective: .lose, rate: 1.0, weightKg: 80) == .muscle)
        #expect(PaceWarning(objective: .lose, rate: 1.8, weightKg: 150) == .medical)
        #expect(PaceWarning(objective: .gain, rate: 0.5, weightKg: 70) == .fat)
        #expect(PaceWarning(objective: .gain, rate: 0.25, weightKg: 70) == nil)
    }

    @Test func customDateRangeReachesThreeYears() throws {
        var answers = OnboardingAnswers()
        answers.objective = .lose
        answers.weightKg = 70
        answers.goalWeightKg = 65
        let range = answers.targetDateRange
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let months = calendar.dateComponents([.month], from: today, to: range.upperBound).month ?? 0
        #expect(months >= 35)
        let february = try #require(calendar.date(byAdding: .month, value: 4, to: today))
        #expect(range.contains(february))
    }
}
