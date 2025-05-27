import Foundation
import SwiftData

@Model
final class MonthlySpending {
    var id: String = UUID().uuidString
    var month: Date = Date()
    var categorySpending: [String: Double] = [:] // Maps category name to amount spent
    
    // Add inverse relationship to FinancialGoal
    @Relationship(inverse: \FinancialGoal.monthlySpending) var goal: FinancialGoal?
    
    init(id: String = UUID().uuidString,
         month: Date = Date(),
         categorySpending: [String: Double] = [:]) {
        self.id = id
        self.month = month
        self.categorySpending = categorySpending
    }
    
    static func createForCurrentMonth() -> MonthlySpending {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        return MonthlySpending(month: startOfMonth)
    }
} 