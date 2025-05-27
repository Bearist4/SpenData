import Foundation
import SwiftData

class MonthlySpendingService {
    static let shared = MonthlySpendingService()
    
    private init() {}
    
    func calculateAndStoreMonthlySpending(modelContext: ModelContext) async {
        print("\n=== CALCULATING MONTHLY SPENDING ===")
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        // Get all transactions and bills
        let transactionDescriptor = FetchDescriptor<Transaction>()
        let billDescriptor = FetchDescriptor<Bill>()
        
        guard let transactions = try? modelContext.fetch(transactionDescriptor),
              let bills = try? modelContext.fetch(billDescriptor) else {
            print("Failed to fetch transactions or bills")
            return
        }
        
        print("Found \(transactions.count) transactions and \(bills.count) bills")
        
        // Filter current month's transactions and bills
        let currentMonthTransactions = transactions.filter { $0.date >= startOfMonth && $0.date < endOfMonth }
        let currentMonthBills = bills.filter { $0.firstInstallment >= startOfMonth && $0.firstInstallment < endOfMonth }
        
        print("\nCurrent month transactions: \(currentMonthTransactions.count)")
        print("Current month bills: \(currentMonthBills.count)")
        
        // Calculate category totals
        var categoryTotals: [String: Double] = [:]
        
        // Process transactions
        for transaction in currentMonthTransactions {
            let category = transaction.category ?? "Uncategorized"
            categoryTotals[category, default: 0] += abs(transaction.amount)
        }
        
        // Process bills
        for bill in currentMonthBills {
            let category = bill.category ?? "Uncategorized"
            let amount = bill.amount ?? 0
            categoryTotals[category, default: 0] += amount
        }
        
        // Print category breakdown
        print("\nCategory breakdown for \(calendar.component(.month, from: now))/\(calendar.component(.year, from: now)):")
        for (category, amount) in categoryTotals.sorted(by: { $0.value > $1.value }) {
            print("\(category): \(FormattingUtils.formatCurrency(amount))")
        }
        
        // Check if we already have a record for this month
        let descriptor = FetchDescriptor<MonthlySpending>(
            predicate: #Predicate<MonthlySpending> { spending in
                spending.month >= startOfMonth && spending.month < endOfMonth
            }
        )
        
        if let existingSpending = try? modelContext.fetch(descriptor).first {
            // Update existing record
            existingSpending.categorySpending = categoryTotals
            print("\nUpdated existing monthly spending record")
        } else {
            // Create new record
            let monthlySpending = MonthlySpending(
                month: startOfMonth,
                categorySpending: categoryTotals
            )
            modelContext.insert(monthlySpending)
            print("\nCreated new monthly spending record")
        }
        
        // Save changes
        do {
            try modelContext.save()
            print("Successfully saved monthly spending data")
        } catch {
            print("Error saving monthly spending data: \(error)")
        }
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