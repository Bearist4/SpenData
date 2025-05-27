import Foundation
import SwiftData
import SwiftUI

enum BudgetingMethod: String, Codable, CaseIterable {
    case fiftyThirtyTwenty = "50/30/20 Rule"
    case seventyTwentyTen = "70/20/10 Rule"
    case sixtyTwentyTwenty = "60/20/20 Rule"
    case thirtyThirtyThirtyTen = "30/30/30/10 Rule"
    case zeroBased = "Zero-Based Budgeting"
    case aggressiveSaving = "Aggressive Saving"
    case eightyTwenty = "80/20 Rule"
    case envelope = "Envelope Method"
    case payYourselfFirst = "Pay Yourself First"
    
    var description: String {
        switch self {
        case .fiftyThirtyTwenty:
            return "Allocate 50% of your income to needs, 30% to wants, and 20% to savings and debt repayment."
        case .seventyTwentyTen:
            return "Spend 70% of your income on living expenses, save 20%, and use 10% for debt repayment or investments."
        case .sixtyTwentyTwenty:
            return "60% Needs, 20% Wants, 20% Savings"
        case .thirtyThirtyThirtyTen:
            return "30% Housing, 30% Daily Expenses, 30% Financial Goals, 10% Personal Development"
        case .zeroBased:
            return "Give every dollar a job. Your income minus expenses should equal zero at the end of each month."
        case .aggressiveSaving:
            return "50-70% Savings, 20-40% Needs, 0-10% Wants"
        case .eightyTwenty:
            return "20% Savings, 80% Everything else"
        case .envelope:
            return "Divide your income into physical or digital envelopes for different spending categories."
        case .payYourselfFirst:
            return "Prioritize saving by automatically setting aside a portion of your income before spending anything."
        }
    }
    
    var bestFor: [String] {
        switch self {
        case .fiftyThirtyTwenty:
            return [
                "Beginners looking for a simple budgeting framework",
                "People with stable income",
                "Those who want a balanced approach to spending and saving"
            ]
        case .seventyTwentyTen:
            return [
                "People with high living expenses",
                "Those focusing on debt repayment",
                "Individuals who want to maintain a good savings rate"
            ]
        case .zeroBased:
            return [
                "Detail-oriented planners",
                "People who want maximum control over their money",
                "Those who need to track every dollar"
            ]
        case .envelope:
            return [
                "People who struggle with overspending",
                "Those who prefer visual budgeting",
                "Individuals who want to limit spending in specific categories"
            ]
        case .payYourselfFirst:
            return [
                "People who want to prioritize saving",
                "Those with irregular income",
                "Individuals who struggle to save consistently"
            ]
        default:
            return []
        }
    }
    
    var defaultPercentages: [String: Double] {
        switch self {
        case .fiftyThirtyTwenty:
            return [
                "Needs": 0.5,
                "Wants": 0.3,
                "Savings": 0.2
            ]
        case .seventyTwentyTen:
            return [
                "Living Expenses": 0.7,
                "Savings": 0.2,
                "Debt/Investments": 0.1
            ]
        case .sixtyTwentyTwenty:
            return ["Needs": 0.6, "Wants": 0.2, "Savings": 0.2]
        case .thirtyThirtyThirtyTen:
            return ["Housing": 0.3, "Daily Expenses": 0.3, "Financial Goals": 0.3, "Personal Development": 0.1]
        case .zeroBased:
            return [:] // Custom percentages required
        case .aggressiveSaving:
            return ["Savings": 0.6, "Needs": 0.3, "Wants": 0.1]
        case .eightyTwenty:
            return ["Savings": 0.2, "Everything Else": 0.8]
        case .envelope:
            return [:] // Custom percentages required
        case .payYourselfFirst:
            return [
                "Savings": 0.2,
                "Expenses": 0.8
            ]
        }
    }
}

enum ExpenseType: String, Codable, CaseIterable {
    case need = "Need"
    case want = "Want"
    case savings = "Savings"
    case debt = "Debt"
    case charity = "Charity"
    case housing = "Housing"
    case dailyExpenses = "Daily Expenses"
    case financialGoals = "Financial Goals"
    case personalDevelopment = "Personal Development"
    case other = "Other"
    
    var color: Color {
        switch self {
        case .need: return .blue
        case .want: return .orange
        case .savings: return .green
        case .debt: return .red
        case .charity: return .purple
        case .housing: return .indigo
        case .dailyExpenses: return .mint
        case .financialGoals: return .teal
        case .personalDevelopment: return .pink
        case .other: return .gray
        }
    }
}

@Model
final class FinancialGoal {
    var id: String?
    var name: String?
    var method: String?
    var targetAmount: Double?
    var currentAmount: Double = 0.0
    var startDate: Date?
    var targetDate: Date?
    var createdAt: Date = Date()
    var isActive: Bool = true
    var customPercentages: [String: Double]?
    
    // Category mappings for expense types
    var categoryMappings: [String: String]? // Maps category names to expense types (need/want/savings)
    
    // Category classifications
    var billCategoryTypes: [String: String]? // Maps bill category to type (need/want/notAccounted)
    var transactionCategoryTypes: [String: String]? // Maps transaction category to type (need/want/notAccounted)
    
    // Relationship to User
    @Relationship(inverse: \User.financialGoals) var user: User?
    
    // Relationship to MonthlySpending
    @Relationship(deleteRule: .cascade) var monthlySpending: [MonthlySpending]?
    
    init(id: String = UUID().uuidString,
         name: String,
         method: BudgetingMethod,
         targetAmount: Double? = nil,
         startDate: Date = Date(),
         targetDate: Date? = nil,
         customPercentages: [String: Double]? = nil,
         categoryMappings: [String: String]? = nil) {
        self.id = id
        self.name = name
        self.method = method.rawValue
        self.targetAmount = targetAmount
        self.startDate = startDate
        self.targetDate = targetDate
        self.customPercentages = customPercentages
        self.categoryMappings = categoryMappings
        self.monthlySpending = []
    }
    
    var methodEnum: BudgetingMethod? {
        guard let methodString = method else { return nil }
        return BudgetingMethod(rawValue: methodString)
    }
    
    var percentages: [String: Double] {
        if let custom = customPercentages {
            return custom
        }
        return methodEnum?.defaultPercentages ?? [:]
    }
    
    var requiredMonthlySavings: Double? {
        guard let targetAmount = targetAmount,
              let targetDate = targetDate,
              let startDate = startDate else { return nil }
        
        let totalMonths = Calendar.current.dateComponents([.month], from: startDate, to: targetDate).month ?? 0
        guard totalMonths > 0 else { return nil }
        
        return (targetAmount - currentAmount) / Double(totalMonths)
    }
    
    func adjustTargetDateForIncome(_ monthlyIncome: Double) -> Date? {
        guard let targetAmount = targetAmount,
              let startDate = startDate else { return nil }
        
        let remainingAmount = targetAmount - currentAmount
        let requiredMonths = ceil(remainingAmount / monthlyIncome)
        
        return Calendar.current.date(byAdding: .month, value: Int(requiredMonths), to: startDate)
    }
    
    func isFeasibleWithIncome(_ monthlyIncome: Double) -> Bool {
        guard let required = requiredMonthlySavings else { return false }
        return required <= monthlyIncome
    }
    
    func getCategoryExpenseType(_ category: String) -> ExpenseType {
        guard let mappings = categoryMappings,
              let typeString = mappings[category],
              let type = ExpenseType(rawValue: typeString) else {
            return .other
        }
        return type
    }
    
    func setCategoryExpenseType(_ category: String, type: ExpenseType) {
        if categoryMappings == nil {
            categoryMappings = [:]
        }
        categoryMappings?[category] = type.rawValue
    }
    
    var needsCategories: [String] {
        var categories: [String] = []
        
        if let billTypes = billCategoryTypes {
            categories.append(contentsOf: billTypes.filter { $0.value == ExpenseType.need.rawValue }.map { $0.key })
        }
        
        if let transactionTypes = transactionCategoryTypes {
            categories.append(contentsOf: transactionTypes.filter { $0.value == ExpenseType.need.rawValue }.map { $0.key })
        }
        
        return categories
    }
    
    var wantsCategories: [String] {
        var categories: [String] = []
        
        if let billTypes = billCategoryTypes {
            categories.append(contentsOf: billTypes.filter { $0.value == ExpenseType.want.rawValue }.map { $0.key })
        }
        
        if let transactionTypes = transactionCategoryTypes {
            categories.append(contentsOf: transactionTypes.filter { $0.value == ExpenseType.want.rawValue }.map { $0.key })
        }
        
        return categories
    }
    
    func getCategoryType(for category: String, isBill: Bool) -> ExpenseType {
        let mappings = isBill ? billCategoryTypes : transactionCategoryTypes
        guard let typeString = mappings?[category],
              let type = ExpenseType(rawValue: typeString) else {
            return .other
        }
        return type
    }
    
    func setCategoryType(_ category: String, type: ExpenseType, isBill: Bool) {
        if isBill {
            if billCategoryTypes == nil {
                billCategoryTypes = [:]
            }
            billCategoryTypes?[category] = type.rawValue
        } else {
            if transactionCategoryTypes == nil {
                transactionCategoryTypes = [:]
            }
            transactionCategoryTypes?[category] = type.rawValue
        }
    }
    
    func getSpendingForMonth(_ date: Date) -> (needs: Double, wants: Double, notAccounted: Double)? {
        guard let spending = getMonthlySpending(for: date) else { return nil }
        
        var needs: Double = 0
        var wants: Double = 0
        var notAccounted: Double = 0
        
        for (category, amount) in spending.categorySpending {
            let type = getCategoryType(for: category, isBill: false)
            switch type {
            case .need:
                needs += amount
            case .want:
                wants += amount
            case .savings, .debt, .charity, .housing, .dailyExpenses, .financialGoals, .personalDevelopment, .other:
                notAccounted += amount
            }
        }
        
        return (needs, wants, notAccounted)
    }

    func getMonthlySpending(for date: Date) -> MonthlySpending? {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        return monthlySpending?.first { spending in
            spending.month >= startOfMonth && spending.month < endOfMonth
        }
    }

    func calculateMonthlySpending(from transactions: [Transaction], bills: [Bill]) -> (needs: Double, wants: Double, notAccounted: Double) {
        var needs: Double = 0
        var wants: Double = 0
        var notAccounted: Double = 0
        
        // Calculate from bills (recurring expenses)
        for bill in bills {
            let category = bill.category ?? "Uncategorized"
            let type = getCategoryType(for: category, isBill: true)
            let amount = bill.amount ?? 0
            
            switch type {
            case .need:
                needs += amount
            case .want:
                wants += amount
            case .savings, .debt, .charity, .housing, .dailyExpenses, .financialGoals, .personalDevelopment, .other:
                notAccounted += amount
            }
        }
        
        // Calculate from transactions (one-time expenses)
        for transaction in transactions {
            let category = transaction.category ?? "Uncategorized"
            let type = getCategoryType(for: category, isBill: false)
            let amount = abs(transaction.amount)
            
            switch type {
            case .need:
                needs += amount
            case .want:
                wants += amount
            case .savings, .debt, .charity, .housing, .dailyExpenses, .financialGoals, .personalDevelopment, .other:
                notAccounted += amount
            }
        }
        
        return (needs, wants, notAccounted)
    }

    func getCategorySpendingForMonth(_ date: Date) -> [String: Double]? {
        return getMonthlySpending(for: date)?.categorySpending
    }

    func printMonthlySpendingDetails() {
        print("\n=== Monthly Spending Details for \(name ?? "Unnamed Goal") ===")
        
        guard let spendingRecords = monthlySpending, !spendingRecords.isEmpty else {
            print("No spending records found")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        
        for spending in spendingRecords.sorted(by: { $0.month < $1.month }) {
            print("\nMonth: \(dateFormatter.string(from: spending.month))")
            
            var needs: Double = 0
            var wants: Double = 0
            var notAccounted: Double = 0
            
            for (category, amount) in spending.categorySpending {
                let type = getCategoryType(for: category, isBill: false)
                switch type {
                case .need:
                    needs += amount
                case .want:
                    wants += amount
                case .savings, .debt, .charity, .housing, .dailyExpenses, .financialGoals, .personalDevelopment, .other:
                    notAccounted += amount
                }
            }
            
            print("Needs: \(FormattingUtils.formatCurrency(needs))")
            print("Wants: \(FormattingUtils.formatCurrency(wants))")
            print("Not Accounted: \(FormattingUtils.formatCurrency(notAccounted))")
            
            print("\nCategory Breakdown:")
            for (category, amount) in spending.categorySpending.sorted(by: { $0.value > $1.value }) {
                print("\(category): \(FormattingUtils.formatCurrency(amount))")
            }
        }
    }

    func printCurrentMonthCategorySpending() {
        print("\n=== Current Month Category Spending for \(name ?? "Unnamed Goal") ===")
        
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        guard let currentMonthSpending = getMonthlySpending(for: startOfMonth) else {
            print("No spending data found for current month")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        print("\nMonth: \(dateFormatter.string(from: currentMonthSpending.month))")
        
        var needs: Double = 0
        var wants: Double = 0
        var notAccounted: Double = 0
        
        for (category, amount) in currentMonthSpending.categorySpending {
            let type = getCategoryType(for: category, isBill: false)
            switch type {
            case .need:
                needs += amount
            case .want:
                wants += amount
            case .savings, .debt, .charity, .housing, .dailyExpenses, .financialGoals, .personalDevelopment, .other:
                notAccounted += amount
            }
        }
        
        print("\nTotals:")
        print("Needs: \(FormattingUtils.formatCurrency(needs))")
        print("Wants: \(FormattingUtils.formatCurrency(wants))")
        print("Not Accounted: \(FormattingUtils.formatCurrency(notAccounted))")
        
        print("\nCategory Breakdown:")
        for (category, amount) in currentMonthSpending.categorySpending.sorted(by: { $0.value > $1.value }) {
            print("\(category): \(FormattingUtils.formatCurrency(amount))")
        }
    }
    
    func calculatePotentialSavings(monthlyIncome: Double, transactions: [Transaction], bills: [Bill]) -> Double {
        guard let method = methodEnum else { return 0 }
        
        let targetNeedsPercentage = method.defaultPercentages["Needs"] ?? 0.5
        let targetWantsPercentage = method.defaultPercentages["Wants"] ?? 0.3
        
        let targetNeedsAmount = monthlyIncome * targetNeedsPercentage
        let targetWantsAmount = monthlyIncome * targetWantsPercentage
        
        // Get current spending
        let currentSpending = calculateMonthlySpending(from: transactions, bills: bills)
        
        // Calculate potential savings based on the difference between target and actual spending
        // For bills, we consider them as fixed expenses
        let billNeeds = bills.filter { getCategoryType(for: $0.category ?? "Uncategorized", isBill: true) == .need }
            .reduce(0) { $0 + ($1.amount ?? 0) }
        let billWants = bills.filter { getCategoryType(for: $0.category ?? "Uncategorized", isBill: true) == .want }
            .reduce(0) { $0 + ($1.amount ?? 0) }
        
        // For transactions, we can adjust them to meet targets
        let transactionNeeds = currentSpending.needs - billNeeds
        let transactionWants = currentSpending.wants - billWants
        
        // Calculate how much we can save by adjusting transaction spending
        let needsDifference = targetNeedsAmount - billNeeds - transactionNeeds
        let wantsDifference = targetWantsAmount - billWants - transactionWants
        
        // Return the sum of potential savings from both categories
        return max(0, needsDifference + wantsDifference)
    }
    
    // MARK: - Secure Storage Methods
    
    private func createCloudKitKey() -> String {
        let sanitizedId = (id ?? UUID().uuidString).replacingOccurrences(of: "-", with: "")
        return "financial_goal_\(sanitizedId)"
    }
    
    func saveSecureData() async throws {
        let secureStorage = SecureStorageService.shared
        
        let goalDataDict: [String: String] = [
            "id": id ?? "",
            "name": name ?? "",
            "method": method ?? "",
            "targetAmount": String(targetAmount ?? 0.0),
            "currentAmount": String(currentAmount),
            "startDate": String(startDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970),
            "targetDate": String(targetDate?.timeIntervalSince1970 ?? 0),
            "createdAt": String(createdAt.timeIntervalSince1970),
            "isActive": String(isActive)
        ]
        
        let cloudKitKey = createCloudKitKey()
        
        let goalData = try JSONEncoder().encode(goalDataDict)
        try secureStorage.saveToKeychain(key: cloudKitKey, data: goalData)
        try await secureStorage.saveToiCloud(key: cloudKitKey, data: goalData)
        
        NotificationCenter.default.post(name: .financialGoalDataDidChange, object: nil)
    }
    
    // MARK: - Migration Methods
    
    static func migrateExistingData(modelContext: ModelContext) async {
        print("\n=== STARTING MIGRATION ===")
        let calendar = Calendar.current
        let now = Date()
        
        // Get all financial goals
        let descriptor = FetchDescriptor<FinancialGoal>()
        guard let goals = try? modelContext.fetch(descriptor) else {
            print("Failed to fetch financial goals")
            return
        }
        print("Found \(goals.count) financial goals")
        
        // Get all transactions and bills
        let transactionDescriptor = FetchDescriptor<Transaction>()
        let billDescriptor = FetchDescriptor<Bill>()
        guard let transactions = try? modelContext.fetch(transactionDescriptor),
              let bills = try? modelContext.fetch(billDescriptor) else {
            print("Failed to fetch transactions or bills")
            return
        }
        print("Found \(transactions.count) transactions and \(bills.count) bills")
        
        for goal in goals {
            print("\nProcessing goal: \(goal.name ?? "Unnamed")")
            print("Current monthly spending records: \(goal.monthlySpending?.count ?? 0)")
            
            // Always update current month's spending
            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let currentMonthEnd = calendar.date(byAdding: .month, value: 1, to: currentMonthStart)!
            
            // Filter current month's transactions and bills
            let currentMonthTransactions = transactions.filter { $0.date >= currentMonthStart && $0.date < currentMonthEnd }
            let currentMonthBills = bills.filter { $0.firstInstallment >= currentMonthStart && $0.firstInstallment < currentMonthEnd }
            
            print("Current month transactions: \(currentMonthTransactions.count)")
            print("Current month bills: \(currentMonthBills.count)")
            
            // Calculate current month's spending
            var categoryTotals: [String: Double] = [:]
            
            // Process current month's transactions
            for transaction in currentMonthTransactions {
                let category = transaction.category ?? "Uncategorized"
                categoryTotals[category, default: 0] += abs(transaction.amount)
            }
            
            // Process current month's bills
            for bill in currentMonthBills {
                let category = bill.category ?? "Uncategorized"
                let amount = bill.amount ?? 0
                categoryTotals[category, default: 0] += amount
            }
            
            print("\nCategory breakdown:")
            for (category, amount) in categoryTotals.sorted(by: { $0.key < $1.key }) {
                print("\(category): \(FormattingUtils.formatCurrency(amount))")
            }
            
            // Create or update current month's spending record
            if let existingSpending = goal.monthlySpending?.first(where: { spending in
                spending.month >= currentMonthStart && spending.month < currentMonthEnd
            }) {
                print("\nUpdating existing spending record for current month")
                existingSpending.categorySpending = categoryTotals
            } else {
                print("\nCreating new spending record for current month")
                let monthlySpending = MonthlySpending(
                    month: currentMonthStart,
                    categorySpending: categoryTotals
                )
                if goal.monthlySpending == nil {
                    goal.monthlySpending = []
                }
                goal.monthlySpending?.append(monthlySpending)
            }
            
            // Save changes after each goal
            do {
                try modelContext.save()
                print("Successfully saved changes for goal: \(goal.name ?? "Unnamed")")
            } catch {
                print("Error saving changes for goal: \(error)")
            }
        }
        
        print("\n=== MIGRATION COMPLETED ===")
    }
} 

