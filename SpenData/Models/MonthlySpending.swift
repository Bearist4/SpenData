import Foundation
import SwiftData

@Model
final class MonthlySpending {
    var id: String = UUID().uuidString
    var month: Date = Date()
    var categorySpending: [String: Double] = [:] // Maps category name to amount spent
    var actualSavings: Double = 0.0 // The actual amount saved in this month
    var targetSavings: Double = 0.0 // The target amount that should have been saved
    var isMonthComplete: Bool = false // Whether the month is complete and savings have been logged
    
    // Add inverse relationship to FinancialGoal
    @Relationship(inverse: \FinancialGoal.monthlySpending) var goal: FinancialGoal?
    
    init(id: String = UUID().uuidString,
         month: Date = Date(),
         categorySpending: [String: Double] = [:],
         actualSavings: Double = 0.0,
         targetSavings: Double = 0.0,
         isMonthComplete: Bool = false) {
        self.id = id
        self.month = month
        self.categorySpending = categorySpending
        self.actualSavings = actualSavings
        self.targetSavings = targetSavings
        self.isMonthComplete = isMonthComplete
    }
    
    static func createForCurrentMonth() -> MonthlySpending {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        return MonthlySpending(month: startOfMonth)
    }
} 