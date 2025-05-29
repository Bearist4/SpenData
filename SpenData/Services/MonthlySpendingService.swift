import Foundation
import SwiftData

class MonthlySpendingService {
    static let shared = MonthlySpendingService()
    
    private init() {}
    
    func calculateAndStoreMonthlySpending(for goal: FinancialGoal, modelContext: ModelContext) async throws {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        // Get all transactions for the current month
        let transactionDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.date >= startOfMonth && transaction.date < endOfMonth
            }
        )
        let transactions = try modelContext.fetch(transactionDescriptor)
        
        // Get all bills for the current month
        let billDescriptor = FetchDescriptor<Bill>(
            predicate: #Predicate<Bill> { bill in
                bill.firstInstallment >= startOfMonth && bill.firstInstallment < endOfMonth
            }
        )
        let bills = try modelContext.fetch(billDescriptor)
        
        // Calculate category spending
        var categorySpending: [String: Double] = [:]
        
        // Process transactions
        for transaction in transactions {
            let category = transaction.category ?? "Uncategorized"
            let amount = abs(transaction.amount)
            categorySpending[category, default: 0] += amount
        }
        
        // Process bills
        for bill in bills {
            let category = bill.category ?? "Uncategorized"
            let amount = bill.amount ?? 0
            categorySpending[category, default: 0] += amount
        }
        
        // Calculate target savings
        let spending = goal.calculateMonthlySpending(from: transactions, bills: bills)
        let totalNeeds = spending.needs
        let totalWants = spending.wants
        let totalNotAccounted = spending.notAccounted
        
        // Get monthly income from the goal's user's incomes
        let incomeDescriptor = FetchDescriptor<Income>()
        let allIncomes = try modelContext.fetch(incomeDescriptor)
        let monthlyIncome = allIncomes.reduce(0.0) { $0 + $1.amount }
        
        let targetSavings = monthlyIncome - totalNeeds - totalWants - totalNotAccounted
        
        // Create or update monthly spending record
        let monthlySpending = MonthlySpending(
            month: startOfMonth,
            categorySpending: categorySpending,
            targetSavings: targetSavings
        )
        
        // Add to goal's monthly spending
        if goal.monthlySpending == nil {
            goal.monthlySpending = []
        }
        goal.monthlySpending?.append(monthlySpending)
        
        try modelContext.save()
    }
    
    func getCurrentMonthSpending(modelContext: ModelContext) -> [String: Double] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        let descriptor = FetchDescriptor<MonthlySpending>(
            predicate: #Predicate<MonthlySpending> { spending in
                spending.month >= startOfMonth && spending.month < endOfMonth
            }
        )
        
        if let currentMonthSpending = try? modelContext.fetch(descriptor).first {
            return currentMonthSpending.categorySpending
        }
        
        return [:]
    }
    
    func printCurrentMonthSpending(modelContext: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        let descriptor = FetchDescriptor<MonthlySpending>(
            predicate: #Predicate<MonthlySpending> { spending in
                spending.month >= startOfMonth && spending.month < endOfMonth
            }
        )
        
        if let currentMonthSpending = try? modelContext.fetch(descriptor).first {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            print("\nMonthly Spending for \(dateFormatter.string(from: currentMonthSpending.month))")
            print("\nCategory breakdown:")
            
            for (category, amount) in currentMonthSpending.categorySpending.sorted(by: { $0.value > $1.value }) {
                print("\(category): \(FormattingUtils.formatCurrency(amount))")
            }
        } else {
            print("No spending data found for current month")
        }
    }
} 