import SwiftUI
import SwiftData
import Charts

struct FinancialGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var goals: [FinancialGoal]
    @Query private var transactions: [Transaction]
    @Query private var bills: [Bill]
    @Query private var incomes: [Income]
    @State private var showingMethodSelection = false
    @State private var selectedGoal: FinancialGoal?
    @State private var showingEditGoal = false
    
    var body: some View {
        List {
            ForEach(goals) { goal in
                GoalListItem(
                    goal: goal,
                    transactions: transactions,
                    bills: bills,
                    incomes: incomes
                )
            }
            .onDelete(perform: deleteGoals)
        }
        .navigationTitle("Financial Goals")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingMethodSelection = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            
            #if DEBUG
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Debug") {
                    print("\n=== DEBUG BUTTON PRESSED ===")
                    print("Number of goals found: \(goals.count)")
                    
                    if goals.isEmpty {
                        print("No goals found to process")
                        return
                    }
                    
                    for goal in goals {
                        print("\nProcessing goal: \(goal.name ?? "Unnamed")")
                        print("Monthly spending records count: \(goal.monthlySpending?.count ?? 0)")
                        
                        goal.printMonthlySpendingDetails()
                        goal.printCurrentMonthCategorySpending()
                    }
                }
            }
            #endif
        }
        .sheet(isPresented: $showingMethodSelection) {
            MethodSelectionView { selectedMethod in
                showingMethodSelection = false
                if let method = selectedMethod {
                    selectedGoal = FinancialGoal(
                        name: "",
                        method: method,
                        targetAmount: nil,
                        startDate: Date(),
                        targetDate: Date().addingTimeInterval(365 * 24 * 60 * 60)
                    )
                    showingEditGoal = true
                }
            }
        }
        .sheet(isPresented: $showingEditGoal) {
            if let goal = selectedGoal {
                AddFinancialGoalView(goal: goal)
            }
        }
    }
    
    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            let goal = goals[index]
            modelContext.delete(goal)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting goals: \(error)")
        }
    }
}

struct GoalListItem: View {
    let goal: FinancialGoal
    let transactions: [Transaction]
    let bills: [Bill]
    let incomes: [Income]
    
    // Add computed properties for calculations
    private var currentMonthBills: [Bill] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        return bills.filter { $0.firstInstallment >= startOfMonth && $0.firstInstallment < endOfMonth }
    }
    
    private var currentMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        return transactions.filter { $0.date >= startOfMonth && $0.date < endOfMonth }
    }
    
    private var uniqueBills: [String: Bill] {
        var bills: [String: Bill] = [:]
        for bill in currentMonthBills {
            if let name = bill.name {
                let key = "\(name)_\(bill.category ?? "Uncategorized")"
                bills[key] = bill
            }
        }
        return bills
    }
    
    private var billNeeds: Double {
        uniqueBills.values
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: true) == .need }
            .reduce(into: 0.0) { result, bill in
                let billAmount = (bill.amount ?? 0).rounded(to: 2)
                let amount = bill.isShared ? (billAmount / Double(bill.numberOfShares)).rounded(to: 2) : billAmount
                result += amount
            }
    }
    
    private var billWants: Double {
        uniqueBills.values
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: true) == .want }
            .reduce(into: 0.0) { result, bill in
                let billAmount = (bill.amount ?? 0).rounded(to: 2)
                let amount = bill.isShared ? (billAmount / Double(bill.numberOfShares)).rounded(to: 2) : billAmount
                result += amount
            }
    }
    
    private var transactionNeeds: Double {
        currentMonthTransactions
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: false) == .need }
            .reduce(into: 0.0) { result, transaction in
                result += abs(transaction.amount)
            }
    }
    
    private var transactionWants: Double {
        currentMonthTransactions
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: false) == .want }
            .reduce(into: 0.0) { result, transaction in
                result += abs(transaction.amount)
            }
    }
    
    private var monthlyIncome: Double {
        incomes.reduce(0) { $0 + $1.amount }
    }
    
    private var totalNeeds: Double {
        billNeeds + transactionNeeds
    }
    
    private var totalWants: Double {
        billWants + transactionWants
    }
    
    private var monthlySavings: Double {
        monthlyIncome - (totalNeeds + totalWants)
    }
    
    private var requiredMonthlySavings: Double {
        goal.requiredMonthlySavings ?? 0
    }
    
    private var savingsProgress: Double {
        requiredMonthlySavings > 0 ? min(monthlySavings / requiredMonthlySavings, 1.0) : 0.0
    }
    
    var body: some View {
        NavigationLink(destination: FinancialGoalDetailView(goal: goal, transactions: transactions, bills: bills, incomes: incomes)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(goal.name ?? "Unnamed Goal")
                        .font(.headline)
                    Spacer()
                    if let method = goal.methodEnum {
                        Text(method.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let method = goal.methodEnum {
                    Text(method.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Month's Progress")
                        .font(.subheadline)
                        .bold()
                    
                    // Monthly Savings Progress
                    HStack {
                        Text("Monthly Savings Goal")
                            .font(.caption)
                        Spacer()
                        Text("\(Int(savingsProgress * 100))%")
                            .font(.caption)
                            .foregroundStyle(savingsProgress >= 1.0 ? .green : .orange)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            Rectangle()
                                .fill(savingsProgress >= 1.0 ? Color.green : Color.orange)
                                .frame(width: geometry.size.width * savingsProgress, height: 8)
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 8)
                    
                    // Current Month's Spending
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Month's Spending")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text("Bills (Needs)")
                                .font(.caption)
                            Spacer()
                            Text(FormattingUtils.formatCurrency(billNeeds))
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        
                        HStack {
                            Text("Bills (Wants)")
                                .font(.caption)
                            Spacer()
                            Text(FormattingUtils.formatCurrency(billWants))
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        
                        HStack {
                            Text("Transactions (Needs)")
                                .font(.caption)
                            Spacer()
                            Text(FormattingUtils.formatCurrency(transactionNeeds))
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        
                        HStack {
                            Text("Transactions (Wants)")
                                .font(.caption)
                            Spacer()
                            Text(FormattingUtils.formatCurrency(transactionWants))
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Monthly Savings")
                                .font(.caption)
                                .bold()
                            Spacer()
                            Text(FormattingUtils.formatCurrency(monthlySavings))
                                .font(.caption)
                                .bold()
                                .foregroundStyle(monthlySavings >= requiredMonthlySavings ? .green : .orange)
                        }
                        
                        if monthlySavings < requiredMonthlySavings {
                            Text("Need to save \(FormattingUtils.formatCurrency(requiredMonthlySavings - monthlySavings)) more this month")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                if let targetAmount = goal.targetAmount {
                    HStack {
                        Text("Target: \(FormattingUtils.formatCurrency(targetAmount))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Current: \(FormattingUtils.formatCurrency(goal.currentAmount))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct MonthRange {
    let start: Date
    let end: Date
    
    static func forDate(_ date: Date) -> MonthRange {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        let startOfMonth = calendar.date(from: components)!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        return MonthRange(start: startOfMonth, end: endOfMonth)
    }
    
    static func nextMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: 1, to: date)!
    }
}

struct FinancialGoalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let goal: FinancialGoal
    let transactions: [Transaction]
    let bills: [Bill]
    let incomes: [Income]
    
    @State private var selectedMonth = Date()
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    private func getTransactionsForMonth(_ date: Date) -> [Transaction] {
        let range = MonthRange.forDate(date)
        return transactions.filter { transaction in
            transaction.date >= range.start && transaction.date < range.end
        }
    }
    
    private func getBillsForMonth(_ date: Date) -> [Bill] {
        let range = MonthRange.forDate(date)
        return bills.filter { bill in
            bill.firstInstallment >= range.start && bill.firstInstallment < range.end
        }
    }
    
    private func getMonthlySavings(for date: Date) -> Double {
        let monthTransactions = getTransactionsForMonth(date)
        let monthBills = getBillsForMonth(date)
        let spending = goal.calculateMonthlySpending(from: monthTransactions, bills: monthBills)
        return monthlyIncome - (spending.needs + spending.wants + spending.notAccounted)
    }
    
    private func getSavingsStatus(for date: Date) -> (status: SavingsStatus, amount: Double) {
        // Don't calculate status for future months
        if date > Date() {
            return (.notCalculated, 0)
        }
        
        let savings = getMonthlySavings(for: date)
        let required = goal.requiredMonthlySavings ?? 0
        
        if savings >= required {
            return (.achieved, savings)
        } else if savings > 0 {
            return (.partial, savings)
        } else {
            return (.notCalculated, savings)
        }
    }
    
    private var monthlyIncome: Double {
        let range = MonthRange.forDate(selectedMonth)
        let filteredIncomes = incomes.filter { income in
            // Check if the income's first payment is before or during the selected month
            income.firstPayment <= range.end &&
            // For monthly incomes, check if they're active in this month
            (income.frequency == IncomeFrequency.monthly.rawValue ||
             // For other frequencies, check if they have a payment in this month
             income.nextPaymentDate >= range.start && income.nextPaymentDate < range.end)
        }
        
        // Debug information
        print("\nMonthly Income Calculation:")
        print("Month: \(selectedMonth.formatted(.dateTime.month().year()))")
        print("Date Range: \(range.start.formatted()) to \(range.end.formatted())")
        print("\nFiltered Incomes:")
        for income in filteredIncomes {
            print("\(income.name ?? "Unnamed"): \(FormattingUtils.formatCurrency(income.amount))")
            print("  First Payment: \(income.firstPayment.formatted())")
            print("  Frequency: \(income.frequency ?? "Unknown")")
            print("  Next Payment: \(income.nextPaymentDate.formatted())")
        }
        
        let total = filteredIncomes.reduce(0.0) { $0 + $1.amount }
        print("\nTotal Monthly Income: \(FormattingUtils.formatCurrency(total))")
        
        return total
    }
    
    private var availableMonths: [Date] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let defaultStartDate = calendar.date(from: components)!
        let startDate = goal.startDate ?? defaultStartDate
        let targetDate = goal.targetDate ?? calendar.date(byAdding: .year, value: 1, to: startDate)!
        
        var months: [Date] = []
        var currentDate = startDate
        
        while currentDate <= targetDate {
            months.append(currentDate)
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
        }
        
        return months
    }
    
    var body: some View {
        List {
            ForEach(availableMonths, id: \.self) { month in
                NavigationLink(destination: MonthDetailView(
                    goal: goal,
                    month: month,
                    transactions: transactions,
                    bills: bills,
                    incomes: incomes
                )) {
                    MonthListItem(
                        month: month,
                        status: getSavingsStatus(for: month),
                        goal: goal,
                        transactions: transactions,
                        bills: bills,
                        incomes: incomes
                    )
                }
            }
        }
        .navigationTitle(goal.name ?? "Financial Goal")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Delete", role: .destructive) {
                    showingDeleteAlert = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddFinancialGoalView(goal: goal)
        }
        .alert("Delete Goal", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteGoal()
            }
        } message: {
            Text("Are you sure you want to delete this goal? This action cannot be undone.")
        }
    }
    
    private func deleteGoal() {
        if let user = goal.user {
            user.financialGoals?.removeAll { $0.id == goal.id }
        }
        modelContext.delete(goal)
        dismiss()
    }
}

enum SavingsStatus {
    case achieved
    case partial
    case notCalculated
    
    var color: Color {
        switch self {
        case .achieved: return .green
        case .partial: return .orange
        case .notCalculated: return .gray
        }
    }
    
    var description: String {
        switch self {
        case .achieved: return "Goal Achieved"
        case .partial: return "Partial Progress"
        case .notCalculated: return "Not Calculated"
        }
    }
}

struct MonthListItem: View {
    let month: Date
    let status: (status: SavingsStatus, amount: Double)
    let goal: FinancialGoal
    let transactions: [Transaction]
    let bills: [Bill]
    let incomes: [Income]
    
    private var monthBills: [Bill] {
        let range = MonthRange.forDate(month)
        return bills.filter { bill in
            bill.firstInstallment >= range.start && bill.firstInstallment < range.end
        }
    }
    
    private var monthTransactions: [Transaction] {
        let range = MonthRange.forDate(month)
        return transactions.filter { transaction in
            transaction.date >= range.start && transaction.date < range.end
        }
    }
    
    private var uniqueBills: [String: Bill] {
        var bills: [String: Bill] = [:]
        for bill in monthBills {
            if let name = bill.name {
                let key = "\(name)_\(bill.category ?? "Uncategorized")"
                bills[key] = bill
            }
        }
        return bills
    }
    
    private var billNeeds: Double {
        uniqueBills.values
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: true) == .need }
            .reduce(into: 0.0) { result, bill in
                let billAmount = (bill.amount ?? 0).rounded(to: 2)
                let amount = bill.isShared ? (billAmount / Double(bill.numberOfShares)).rounded(to: 2) : billAmount
                result += amount
            }
    }
    
    private var billWants: Double {
        uniqueBills.values
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: true) == .want }
            .reduce(into: 0.0) { result, bill in
                let billAmount = (bill.amount ?? 0).rounded(to: 2)
                let amount = bill.isShared ? (billAmount / Double(bill.numberOfShares)).rounded(to: 2) : billAmount
                result += amount
            }
    }
    
    private var transactionNeeds: Double {
        monthTransactions
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: false) == .need }
            .reduce(into: 0.0) { result, transaction in
                result += abs(transaction.amount)
            }
    }
    
    private var transactionWants: Double {
        monthTransactions
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: false) == .want }
            .reduce(into: 0.0) { result, transaction in
                result += abs(transaction.amount)
            }
    }
    
    private var monthlyIncome: Double {
        let range = MonthRange.forDate(month)
        let filteredIncomes = incomes.filter { income in
            income.firstPayment <= range.end &&
            (income.frequency == IncomeFrequency.monthly.rawValue ||
             income.nextPaymentDate >= range.start && income.nextPaymentDate < range.end)
        }
        return filteredIncomes.reduce(0.0) { $0 + $1.amount }
    }
    
    private var totalNeeds: Double {
        billNeeds + transactionNeeds
    }
    
    private var totalWants: Double {
        billWants + transactionWants
    }
    
    private var monthlySavings: Double {
        monthlyIncome - (totalNeeds + totalWants)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(month.formatted(.dateTime.month().year()))
                    .font(.headline)
                Text(status.status.description)
                    .font(.caption)
                    .foregroundStyle(status.status.color)
            }
            
            Spacer()
            
            Text(FormattingUtils.formatCurrency(monthlySavings))
                .foregroundStyle(status.status.color)
        }
        .padding(.vertical, 4)
    }
}

struct MonthDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let goal: FinancialGoal
    let month: Date
    let transactions: [Transaction]
    let bills: [Bill]
    let incomes: [Income]
    
    @Query private var allIncomes: [Income]
    @State private var showingActualSavingsInput = false
    @State private var actualSavingsAmount: String = ""
    
    private var monthlySpending: MonthlySpending? {
        goal.monthlySpending?.first { Calendar.current.isDate($0.month, equalTo: month, toGranularity: .month) }
    }
    
    private var monthlyIncome: Double {
        let range = MonthRange.forDate(month)
        let filteredIncomes = incomes.filter { income in
            // Check if the income's first payment is before or during the selected month
            income.firstPayment <= range.end &&
            // For monthly incomes, check if they're active in this month
            (income.frequency == IncomeFrequency.monthly.rawValue ||
             // For other frequencies, check if they have a payment in this month
             income.nextPaymentDate >= range.start && income.nextPaymentDate < range.end)
        }
        
        // Debug information
        print("\nMonthly Income Calculation:")
        print("Month: \(month.formatted(.dateTime.month().year()))")
        print("Date Range: \(range.start.formatted()) to \(range.end.formatted())")
        print("\nFiltered Incomes:")
        for income in filteredIncomes {
            print("\(income.name ?? "Unnamed"): \(FormattingUtils.formatCurrency(income.amount))")
            print("  First Payment: \(income.firstPayment.formatted())")
            print("  Frequency: \(income.frequency ?? "Unknown")")
            print("  Next Payment: \(income.nextPaymentDate.formatted())")
        }
        
        let total = filteredIncomes.reduce(0.0) { $0 + $1.amount }
        print("\nTotal Monthly Income: \(FormattingUtils.formatCurrency(total))")
        
        return total
    }
    
    private var spending: (needs: Double, wants: Double, notAccounted: Double) {
        let monthTransactions = getTransactionsForMonth(month)
        let monthBills = getBillsForMonth(month)
        
        // Calculate spending from transactions and bills
        let spending = goal.calculateMonthlySpending(from: monthTransactions, bills: monthBills)
        
        // Debug information
        print("\n=== Month Detail View Debug ===")
        print("Month: \(month.formatted(.dateTime.month().year()))")
        print("Number of transactions: \(monthTransactions.count)")
        print("Number of bills: \(monthBills.count)")
        
        // Print bill details
        print("\nBills:")
        for bill in monthBills {
            print("\(bill.category ?? "Uncategorized"): \(FormattingUtils.formatCurrency(bill.amount ?? 0))")
        }
        
        // Print transaction details
        print("\nTransactions:")
        for transaction in monthTransactions {
            print("\(transaction.category ?? "Uncategorized"): \(FormattingUtils.formatCurrency(abs(transaction.amount)))")
        }
        
        print("\nCalculated Spending:")
        print("Needs: \(FormattingUtils.formatCurrency(spending.needs))")
        print("Wants: \(FormattingUtils.formatCurrency(spending.wants))")
        print("Not Accounted: \(FormattingUtils.formatCurrency(spending.notAccounted))")
        
        return spending
    }
    
    private var billNeeds: Double {
        let monthBills = getBillsForMonth(month)
        print("\n=== Detailed Bill Needs Calculation ===")
        print("Total bills found: \(monthBills.count)")
        
        // Create a dictionary to store unique bills by name
        var uniqueBills: [String: Bill] = [:]
        for bill in monthBills {
            if let name = bill.name {
                uniqueBills[name] = bill
            }
        }
        
        print("\nUnique bills found: \(uniqueBills.count)")
        
        let needs = uniqueBills.values
            .filter { bill in
                let category = bill.category ?? "Uncategorized"
                let type = goal.getCategoryType(for: category, isBill: true)
                let isNeed = type == .need
                print("\nBill: \(bill.name ?? "Unnamed")")
                print("Category: \(category)")
                print("Type: \(type.rawValue)")
                print("Is Need: \(isNeed)")
                print("Amount: \(bill.amount ?? 0)")
                print("Is Shared: \(bill.isShared)")
                print("Number of Shares: \(bill.numberOfShares)")
                return isNeed
            }
            .reduce(into: 0.0) { result, bill in
                let billAmount = (bill.amount ?? 0).rounded(to: 2)
                // If bill is shared, divide by number of shares. If not shared, use full amount
                let amount = bill.isShared ? (billAmount / Double(bill.numberOfShares)).rounded(to: 2) : billAmount
                print("\nCalculating amount for: \(bill.name ?? "Unnamed")")
                print("Original amount: \(billAmount)")
                print("Is Shared: \(bill.isShared)")
                print("Number of Shares: \(bill.numberOfShares)")
                print("Final amount: \(amount)")
                result = (result + amount).rounded(to: 2)
                print("Running total: \(result)")
            }
        
        print("\nFinal Total Bill Needs: \(FormattingUtils.formatCurrency(needs))")
        print("=== End Bill Needs Calculation ===\n")
        
        return needs
    }
    
    private var billWants: Double {
        let monthBills = getBillsForMonth(month)
        let wants = monthBills
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: true) == .want }
            .reduce(into: 0.0) { result, bill in
                // Calculate the actual amount based on whether the bill is shared
                let billAmount = bill.amount / Double(bill.isShared ? bill.numberOfShares : 1)
                result += billAmount
            }
        
        // Debug information
        print("\nBill Wants Calculation:")
        for bill in monthBills where goal.getCategoryType(for: bill.category ?? "Uncategorized", isBill: true) == .want {
            let billAmount = bill.amount / Double(bill.isShared ? bill.numberOfShares : 1)
            print("\(bill.category ?? "Uncategorized"): \(FormattingUtils.formatCurrency(billAmount))")
        }
        print("Total Bill Wants: \(FormattingUtils.formatCurrency(wants))")
        
        return wants
    }
    
    private var transactionNeeds: Double {
        let monthTransactions = getTransactionsForMonth(month)
        let needs = monthTransactions
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: false) == .need }
            .reduce(into: 0.0) { result, transaction in
                // Use absolute value for expenses
                result += abs(transaction.amount)
            }
        
        // Debug information
        print("\nTransaction Needs Calculation:")
        for transaction in monthTransactions where goal.getCategoryType(for: transaction.category ?? "Uncategorized", isBill: false) == .need {
            print("\(transaction.category ?? "Uncategorized"): \(FormattingUtils.formatCurrency(abs(transaction.amount)))")
        }
        print("Total Transaction Needs: \(FormattingUtils.formatCurrency(needs))")
        
        return needs
    }
    
    private var transactionWants: Double {
        let monthTransactions = getTransactionsForMonth(month)
        let wants = monthTransactions.filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: false) == .want }
            .reduce(0) { $0 + abs($1.amount) }
        
        // Debug information
        print("\nTransaction Wants Calculation:")
        for transaction in monthTransactions where goal.getCategoryType(for: transaction.category ?? "Uncategorized", isBill: false) == .want {
            print("\(transaction.category ?? "Uncategorized"): \(FormattingUtils.formatCurrency(abs(transaction.amount)))")
        }
        print("Total Transaction Wants: \(FormattingUtils.formatCurrency(wants))")
        
        return wants
    }
    
    private var monthlySavings: Double {
        // Get all transactions and bills for the selected month
        let monthTransactions = getTransactionsForMonth(month)
        let monthBills = getBillsForMonth(month)
        
        // Calculate transaction expenses
        let transactionExpenses = monthTransactions.reduce(into: 0.0) { result, transaction in
            result += abs(transaction.amount)
        }
        
        // Calculate bill expenses
        let billExpenses = monthBills.reduce(into: 0.0) { result, bill in
            // Calculate the actual amount based on whether the bill is shared
            let billAmount = bill.amount / Double(bill.isShared ? bill.numberOfShares : 1)
            result += billAmount
        }
        
        // Calculate total expenses
        let totalExpenses = transactionExpenses + billExpenses
        
        // Calculate savings as income minus expenses
        let savings = monthlyIncome - totalExpenses
        
        // Debug information
        print("\nMonthly Savings Calculation:")
        print("Monthly Income: \(FormattingUtils.formatCurrency(monthlyIncome))")
        print("Transaction Expenses: \(FormattingUtils.formatCurrency(transactionExpenses))")
        print("Bill Expenses: \(FormattingUtils.formatCurrency(billExpenses))")
        print("Total Expenses: \(FormattingUtils.formatCurrency(totalExpenses))")
        print("Monthly Savings: \(FormattingUtils.formatCurrency(savings))")
        
        return savings
    }
    
    private var requiredMonthlySavings: Double {
        goal.requiredMonthlySavings ?? 0
    }
    
    private var targetNeedsAmount: Double {
        guard let method = goal.methodEnum else { return 0 }
        return monthlyIncome * (method.defaultPercentages["Needs"] ?? 0.5)
    }
    
    private var targetWantsAmount: Double {
        guard let method = goal.methodEnum else { return 0 }
        return monthlyIncome * (method.defaultPercentages["Wants"] ?? 0.3)
    }
    
    private var totalNeeds: Double {
        let monthBills = getBillsForMonth(month)
        let monthTransactions = getTransactionsForMonth(month)
        
        print("\n=== Total Needs Calculation ===")
        
        // Create a dictionary to track unique bills by name and category
        var uniqueBills: [String: Bill] = [:]
        for bill in monthBills {
            if let name = bill.name {
                let key = "\(name)_\(bill.category ?? "Uncategorized")"
                uniqueBills[key] = bill
            }
        }
        
        print("\nUnique bills found: \(uniqueBills.count)")
        
        // Calculate bill needs from unique bills
        let billNeeds = uniqueBills.values
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: true) == .need }
            .reduce(into: 0.0) { result, bill in
                let billAmount = (bill.amount ?? 0).rounded(to: 2)
                let amount = bill.isShared ? (billAmount / Double(bill.numberOfShares)).rounded(to: 2) : billAmount
                print("\nBill: \(bill.name ?? "Unnamed")")
                print("Category: \(bill.category ?? "Uncategorized")")
                print("Original amount: \(billAmount)")
                print("Is shared: \(bill.isShared)")
                print("Number of shares: \(bill.numberOfShares)")
                print("Final amount: \(amount)")
                result += amount
                print("Running total: \(result)")
            }
        
        print("\nTotal Bill Needs: \(billNeeds)")
        
        // Calculate transaction needs
        let transactionNeeds = monthTransactions
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: false) == .need }
            .reduce(into: 0.0) { result, transaction in
                let amount = abs(transaction.amount)
                print("\nTransaction: \(transaction.name ?? "Unnamed")")
                print("Category: \(transaction.category ?? "Uncategorized")")
                print("Amount: \(amount)")
                result += amount
                print("Running total: \(result)")
            }
        
        print("\nTotal Transaction Needs: \(transactionNeeds)")
        
        let total = billNeeds + transactionNeeds
        print("\nFinal Total Needs: \(total)")
        print("=== End Total Needs Calculation ===\n")
        
        return total
    }
    
    private var totalWants: Double {
        let monthBills = getBillsForMonth(month)
        let monthTransactions = getTransactionsForMonth(month)
        
        // Calculate bill wants
        let billWants = monthBills
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: true) == .want }
            .reduce(into: 0.0) { result, bill in
                let billAmount = (bill.amount ?? 0).rounded(to: 2)
                let amount = bill.isShared ? (billAmount / Double(bill.numberOfShares)).rounded(to: 2) : billAmount
                result += amount
            }
        
        // Calculate transaction wants
        let transactionWants = monthTransactions
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: false) == .want }
            .reduce(into: 0.0) { result, transaction in
                result += abs(transaction.amount)
            }
        
        return billWants + transactionWants
    }
    
    private var savingsProgress: Double {
        guard requiredMonthlySavings > 0 else { return 0 }
        let progress = monthlySavings / requiredMonthlySavings
        return min(max(progress, 0), 1.0) // Clamp between 0 and 1
    }
    
    private var needsProgress: Double {
        guard targetNeedsAmount > 0 else { return 0 }
        let progress = totalNeeds / targetNeedsAmount
        return min(max(progress, 0), 1.0) // Clamp between 0 and 1
    }
    
    private var wantsProgress: Double {
        guard targetWantsAmount > 0 else { return 0 }
        let progress = totalWants / targetWantsAmount
        return min(max(progress, 0), 1.0) // Clamp between 0 and 1
    }
    
    init(goal: FinancialGoal, month: Date, transactions: [Transaction], bills: [Bill], incomes: [Income]) {
        self.goal = goal
        self.month = month
        self.transactions = transactions
        self.bills = bills
        self.incomes = incomes
        _allIncomes = Query()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Required Monthly Savings
                VStack(spacing: 8) {
                    Text("Required Monthly Savings")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(FormattingUtils.formatCurrency(goal.requiredMonthlySavings ?? 0))
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Actual Savings Comparison
                VStack(spacing: 8) {
                    Text("Actual Savings")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if let spending = monthlySpending, spending.isMonthComplete {
                        VStack(spacing: 4) {
                            Text(FormattingUtils.formatCurrency(spending.actualSavings))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(spending.actualSavings >= spending.targetSavings ? .green : .red)
                            
                            Text("Target: \(FormattingUtils.formatCurrency(spending.targetSavings))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            let difference = spending.actualSavings - spending.targetSavings
                            Text(difference >= 0 ? "+\(FormattingUtils.formatCurrency(difference))" : FormattingUtils.formatCurrency(difference))
                                .font(.subheadline)
                                .foregroundColor(difference >= 0 ? .green : .red)
                        }
                    } else {
                        Button(action: { showingActualSavingsInput = true }) {
                            Text("Log Actual Savings")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Budget Allocation
                VStack(spacing: 8) {
                    Text("Budget Allocation")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    // Needs Progress
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Needs")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(needsProgress * 100))%")
                                .font(.subheadline)
                                .foregroundStyle(needsProgress <= 1.0 ? .blue : .red)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .fill(needsProgress <= 1.0 ? Color.blue : Color.red)
                                    .frame(width: min(geometry.size.width * needsProgress, geometry.size.width), height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                        
                        HStack {
                            Text(FormattingUtils.formatCurrency(totalNeeds))
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Spacer()
                            Text("Target: \(FormattingUtils.formatCurrency(targetNeedsAmount))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Wants Progress
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Wants")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(wantsProgress * 100))%")
                                .font(.subheadline)
                                .foregroundStyle(wantsProgress <= 1.0 ? .orange : .red)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .fill(wantsProgress <= 1.0 ? Color.orange : Color.red)
                                    .frame(width: min(geometry.size.width * wantsProgress, geometry.size.width), height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                        
                        HStack {
                            Text(FormattingUtils.formatCurrency(totalWants))
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Spacer()
                            Text("Target: \(FormattingUtils.formatCurrency(targetWantsAmount))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Spending Breakdown
                VStack(spacing: 8) {
                    Text("Spending Breakdown")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    // Bills (Needs)
                    HStack {
                        Text("Bills (Needs)")
                            .font(.subheadline)
                        Spacer()
                        Text(FormattingUtils.formatCurrency(billNeeds))
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    
                    // Bills (Wants)
                    HStack {
                        Text("Bills (Wants)")
                            .font(.subheadline)
                        Spacer()
                        Text(FormattingUtils.formatCurrency(billWants))
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    
                    // Transactions (Needs)
                    HStack {
                        Text("Transactions (Needs)")
                            .font(.subheadline)
                        Spacer()
                        Text(FormattingUtils.formatCurrency(transactionNeeds))
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    
                    // Transactions (Wants)
                    HStack {
                        Text("Transactions (Wants)")
                            .font(.subheadline)
                        Spacer()
                        Text(FormattingUtils.formatCurrency(transactionWants))
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    
                    Divider()
                    
                    // Monthly Income
                    HStack {
                        Text("Monthly Income")
                            .font(.subheadline)
                            .bold()
                        Spacer()
                        Text(FormattingUtils.formatCurrency(monthlyIncome))
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.green)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            .padding()
        }
        .sheet(isPresented: $showingActualSavingsInput) {
            NavigationView {
                Form {
                    Section(header: Text("Enter Actual Savings")) {
                        TextField("Amount", text: $actualSavingsAmount)
                            .keyboardType(.decimalPad)
                    }
                }
                .navigationTitle("Log Savings")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingActualSavingsInput = false
                    },
                    trailing: Button("Save") {
                        saveActualSavings()
                    }
                )
            }
        }
    }
    
    private func saveActualSavings() {
        guard let amount = Double(actualSavingsAmount) else { return }
        
        if let existingSpending = monthlySpending {
            existingSpending.actualSavings = amount
            existingSpending.isMonthComplete = true
        } else {
            let targetSavings = goal.requiredMonthlySavings ?? 0
            let newSpending = MonthlySpending(
                month: month,
                actualSavings: amount,
                targetSavings: targetSavings,
                isMonthComplete: true
            )
            if goal.monthlySpending == nil {
                goal.monthlySpending = []
            }
            goal.monthlySpending?.append(newSpending)
        }
        
        try? modelContext.save()
        showingActualSavingsInput = false
    }
    
    private func getTransactionsForMonth(_ date: Date) -> [Transaction] {
        let range = MonthRange.forDate(date)
        return transactions.filter { transaction in
            transaction.date >= range.start && transaction.date < range.end
        }
    }
    
    private func getBillsForMonth(_ date: Date) -> [Bill] {
        let range = MonthRange.forDate(date)
        return bills.filter { bill in
            bill.firstInstallment >= range.start && bill.firstInstallment < range.end
        }
    }
}

struct MethodSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let onMethodSelected: (BudgetingMethod?) -> Void
    
    @State private var currentIndex = 0
    private let methods = BudgetingMethod.allCases
    
    var body: some View {
        NavigationStack {
            VStack {
                TabView(selection: $currentIndex) {
                    ForEach(Array(methods.enumerated()), id: \.element) { index, method in
                        MethodCard(method: method) {
                            onMethodSelected(method)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Button("Skip for now") {
                    onMethodSelected(nil)
                }
                .padding()
            }
            .navigationTitle("Choose a Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onMethodSelected(nil)
                    }
                }
            }
        }
    }
}

struct MethodCard: View {
    let method: BudgetingMethod
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text(method.rawValue)
                .font(.title)
                .bold()
            
            Text(method.description)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Best for:")
                    .font(.headline)
                
                ForEach(method.bestFor, id: \.self) { scenario in
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(scenario)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Button(action: onSelect) {
                Text("Use this method")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct AddFinancialGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    @Query private var incomes: [Income]
    @Query private var transactions: [Transaction]
    @Query private var bills: [Bill]
    
    let goal: FinancialGoal
    
    @State private var name = ""
    @State private var targetAmount = ""
    @State private var targetDate: Date
    @State private var selectedIncomes: Set<Income> = []
    @State private var showingDateAdjustmentAlert = false
    @State private var adjustedDate: Date?
    @State private var billCategoryTypes: [String: ExpenseType] = [:]
    @State private var transactionCategoryTypes: [String: ExpenseType] = [:]
    @State private var selectedMonth: Date = Date()
    @State private var currentStep = 1
    @State private var showingAutoClassifyAlert = false
    
    private func getTransactionsForMonth(_ date: Date) -> [Transaction] {
        let range = MonthRange.forDate(date)
        return transactions.filter { transaction in
            transaction.date >= range.start && transaction.date < range.end
        }
    }
    
    private func getBillsForMonth(_ date: Date) -> [Bill] {
        let range = MonthRange.forDate(date)
        return bills.filter { bill in
            bill.firstInstallment >= range.start && bill.firstInstallment < range.end
        }
    }
    
    private var availableMonths: [Date] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let defaultStartDate = calendar.date(from: components)!
        let startDate = goal.startDate ?? defaultStartDate
        let targetDate = goal.targetDate ?? calendar.date(byAdding: .year, value: 1, to: startDate)!
        
        var months: [Date] = []
        var currentDate = startDate
        
        while currentDate <= targetDate {
            months.append(currentDate)
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
        }
        
        return months
    }
    
    init(goal: FinancialGoal) {
        self.goal = goal
        _name = State(initialValue: goal.name ?? "")
        _targetAmount = State(initialValue: String(goal.targetAmount ?? 0))
        _targetDate = State(initialValue: goal.targetDate ?? Date().addingTimeInterval(365 * 24 * 60 * 60))
        
        // Initialize category types
        var initialBillTypes: [String: ExpenseType] = [:]
        if let types = goal.billCategoryTypes {
            for (category, typeString) in types {
                if let type = ExpenseType(rawValue: typeString) {
                    initialBillTypes[category] = type
                }
            }
        }
        _billCategoryTypes = State(initialValue: initialBillTypes)
        
        var initialTransactionTypes: [String: ExpenseType] = [:]
        if let types = goal.transactionCategoryTypes {
            for (category, typeString) in types {
                if let type = ExpenseType(rawValue: typeString) {
                    initialTransactionTypes[category] = type
                }
            }
        }
        _transactionCategoryTypes = State(initialValue: initialTransactionTypes)
    }
    
    private var totalSelectedIncome: Double {
        selectedIncomes.reduce(0) { $0 + $1.amount }
    }
    
    private var monthlyIncome: Double {
        let range = MonthRange.forDate(selectedMonth)
        let filteredIncomes = incomes.filter { income in
            // Check if the income's first payment is before or during the selected month
            income.firstPayment <= range.end &&
            // For monthly incomes, check if they're active in this month
            (income.frequency == IncomeFrequency.monthly.rawValue ||
             // For other frequencies, check if they have a payment in this month
             income.nextPaymentDate >= range.start && income.nextPaymentDate < range.end)
        }
        
        // Debug information
        print("\nMonthly Income Calculation:")
        print("Month: \(selectedMonth.formatted(.dateTime.month().year()))")
        print("Date Range: \(range.start.formatted()) to \(range.end.formatted())")
        print("\nFiltered Incomes:")
        for income in filteredIncomes {
            print("\(income.name ?? "Unnamed"): \(FormattingUtils.formatCurrency(income.amount))")
            print("  First Payment: \(income.firstPayment.formatted())")
            print("  Frequency: \(income.frequency ?? "Unknown")")
            print("  Next Payment: \(income.nextPaymentDate.formatted())")
        }
        
        let total = filteredIncomes.reduce(0.0) { $0 + $1.amount }
        print("\nTotal Monthly Income: \(FormattingUtils.formatCurrency(total))")
        
        return total
    }
    
    private var spending: (needs: Double, wants: Double, notAccounted: Double) {
        if let historicalSpending = goal.getSpendingForMonth(selectedMonth) {
            return historicalSpending
        }
        let monthTransactions = getTransactionsForMonth(selectedMonth)
        let monthBills = getBillsForMonth(selectedMonth)
        return goal.calculateMonthlySpending(from: monthTransactions, bills: monthBills)
    }
    
    private var potentialSavings: Double {
        goal.calculatePotentialSavings(monthlyIncome: monthlyIncome, transactions: transactions, bills: bills)
    }
    
    private var targetNeedsAmount: Double {
        guard let method = goal.methodEnum else { return 0 }
        return monthlyIncome * (method.defaultPercentages["Needs"] ?? 0.5)
    }
    
    private var targetWantsAmount: Double {
        guard let method = goal.methodEnum else { return 0 }
        return monthlyIncome * (method.defaultPercentages["Wants"] ?? 0.3)
    }
    
    private var totalNeeds: Double {
        let monthBills = getBillsForMonth(selectedMonth)
        let monthTransactions = getTransactionsForMonth(selectedMonth)
        
        print("\n=== Total Needs Calculation ===")
        
        // Create a dictionary to track unique bills by name and category
        var uniqueBills: [String: Bill] = [:]
        for bill in monthBills {
            if let name = bill.name {
                let key = "\(name)_\(bill.category ?? "Uncategorized")"
                uniqueBills[key] = bill
            }
        }
        
        print("\nUnique bills found: \(uniqueBills.count)")
        
        // Calculate bill needs from unique bills
        let billNeeds = uniqueBills.values
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: true) == .need }
            .reduce(into: 0.0) { result, bill in
                let billAmount = (bill.amount ?? 0).rounded(to: 2)
                let amount = bill.isShared ? (billAmount / Double(bill.numberOfShares)).rounded(to: 2) : billAmount
                print("\nBill: \(bill.name ?? "Unnamed")")
                print("Category: \(bill.category ?? "Uncategorized")")
                print("Original amount: \(billAmount)")
                print("Is shared: \(bill.isShared)")
                print("Number of shares: \(bill.numberOfShares)")
                print("Final amount: \(amount)")
                result += amount
                print("Running total: \(result)")
            }
        
        print("\nTotal Bill Needs: \(billNeeds)")
        
        // Calculate transaction needs
        let transactionNeeds = monthTransactions
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: false) == .need }
            .reduce(into: 0.0) { result, transaction in
                let amount = abs(transaction.amount)
                print("\nTransaction: \(transaction.name ?? "Unnamed")")
                print("Category: \(transaction.category ?? "Uncategorized")")
                print("Amount: \(amount)")
                result += amount
                print("Running total: \(result)")
            }
        
        print("\nTotal Transaction Needs: \(transactionNeeds)")
        
        let total = billNeeds + transactionNeeds
        print("\nFinal Total Needs: \(total)")
        print("=== End Total Needs Calculation ===\n")
        
        return total
    }
    
    private var totalWants: Double {
        let monthBills = getBillsForMonth(selectedMonth)
        let monthTransactions = getTransactionsForMonth(selectedMonth)
        
        // Calculate bill wants
        let billWants = monthBills
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: true) == .want }
            .reduce(into: 0.0) { result, bill in
                let billAmount = (bill.amount ?? 0).rounded(to: 2)
                let amount = bill.isShared ? (billAmount / Double(bill.numberOfShares)).rounded(to: 2) : billAmount
                result += amount
            }
        
        // Calculate transaction wants
        let transactionWants = monthTransactions
            .filter { goal.getCategoryType(for: $0.category ?? "Uncategorized", isBill: false) == .want }
            .reduce(into: 0.0) { result, transaction in
                result += abs(transaction.amount)
            }
        
        return billWants + transactionWants
    }
    
    private var needsProgress: Double {
        guard targetNeedsAmount > 0 else { return 0 }
        let progress = totalNeeds / targetNeedsAmount
        return min(max(progress, 0), 1.0) // Clamp between 0 and 1
    }
    
    private var wantsProgress: Double {
        guard targetWantsAmount > 0 else { return 0 }
        let progress = totalWants / targetWantsAmount
        return min(max(progress, 0), 1.0) // Clamp between 0 and 1
    }
    
    private var categorySpending: [String: Double] {
        goal.getCategorySpendingForMonth(selectedMonth) ?? [:]
    }
    
    private var monthlySavings: Double {
        // Get all transactions and bills for the selected month
        let monthTransactions = getTransactionsForMonth(selectedMonth)
        let monthBills = getBillsForMonth(selectedMonth)
        
        // Calculate transaction expenses
        let transactionExpenses = monthTransactions.reduce(into: 0.0) { result, transaction in
            result += abs(transaction.amount)
        }
        
        // Calculate bill expenses
        let billExpenses = monthBills.reduce(into: 0.0) { result, bill in
            // Calculate the actual amount based on whether the bill is shared
            let billAmount = bill.amount / Double(bill.isShared ? bill.numberOfShares : 1)
            result += billAmount
        }
        
        // Calculate total expenses
        let totalExpenses = transactionExpenses + billExpenses
        
        // Calculate savings as income minus expenses
        let savings = monthlyIncome - totalExpenses
        
        // Debug information
        print("\nMonthly Savings Calculation:")
        print("Monthly Income: \(FormattingUtils.formatCurrency(monthlyIncome))")
        print("Transaction Expenses: \(FormattingUtils.formatCurrency(transactionExpenses))")
        print("Bill Expenses: \(FormattingUtils.formatCurrency(billExpenses))")
        print("Total Expenses: \(FormattingUtils.formatCurrency(totalExpenses))")
        print("Monthly Savings: \(FormattingUtils.formatCurrency(savings))")
        
        return savings
    }
    
    private var requiredMonthlySavings: Double {
        guard let targetAmount = goal.targetAmount,
              let targetDate = goal.targetDate,
              let startDate = goal.startDate else { return 0 }
        
        let totalMonths = Calendar.current.dateComponents([.month], from: startDate, to: targetDate).month ?? 0
        guard totalMonths > 0 else { return 0 }
        
        return (targetAmount - goal.currentAmount) / Double(totalMonths)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Step 1: Basic Goal Information
                if currentStep == 1 {
                    Section("Goal Details") {
                        TextField("Goal Name", text: $name)
                        
                        TextField("Target Amount", text: $targetAmount)
                            .keyboardType(.decimalPad)
                        
                        DatePicker("Target Date", selection: $targetDate, displayedComponents: [.date])
                    }
                    
                    Section {
                        Button("Next: Choose Income Sources") {
                            withAnimation {
                                currentStep = 2
                            }
                        }
                        .disabled(name.isEmpty || targetAmount.isEmpty)
                    }
                }
                
                // Step 2: Income Sources
                if currentStep == 2 {
                    Section("Income Sources") {
                        ForEach(incomes) { income in
                            Toggle(isOn: Binding(
                                get: { selectedIncomes.contains(income) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedIncomes.insert(income)
                                    } else {
                                        selectedIncomes.remove(income)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading) {
                                    Text(income.name ?? "Unnamed Income")
                                    Text(FormattingUtils.formatCurrency(income.amount))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    if !selectedIncomes.isEmpty {
                        Section {
                            Button("Next: Analyze Spending") {
                                withAnimation {
                                    currentStep = 3
                                }
                            }
                        }
                    }
                }
                
                // Step 3: Spending Analysis
                if currentStep == 3 {
                    Section("Monthly Budget") {
                        DatePicker("Select Month", selection: $selectedMonth, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                        
                        HStack {
                            Text("Total Monthly Income")
                            Spacer()
                            Text(FormattingUtils.formatCurrency(monthlyIncome))
                                .bold()
                        }
                        
                        if let method = goal.methodEnum {
                            HStack {
                                Text("Target Needs (50%)")
                                Spacer()
                                Text(FormattingUtils.formatCurrency(targetNeedsAmount))
                                    .foregroundStyle(.blue)
                            }
                            
                            HStack {
                                Text("Target Wants (30%)")
                                Spacer()
                                Text(FormattingUtils.formatCurrency(targetWantsAmount))
                                    .foregroundStyle(.orange)
                            }
                            
                            HStack {
                                Text("Target Savings (20%)")
                                Spacer()
                                Text(FormattingUtils.formatCurrency(monthlyIncome * 0.2))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    
                    Section("Current Spending") {
                        // Bills (Recurring Expenses)
                        HStack {
                            Text("Recurring Bills")
                                .font(.headline)
                            Spacer()
                        }
                        
                        let billNeeds = bills.filter { getCategoryType(for: $0.category ?? "Uncategorized", isBill: true) == .need }
                            .reduce(0) { $0 + ($1.amount ?? 0) }
                        let billWants = bills.filter { getCategoryType(for: $0.category ?? "Uncategorized", isBill: true) == .want }
                            .reduce(0) { $0 + ($1.amount ?? 0) }
                        
                        HStack {
                            Text("Bills (Needs)")
                            Spacer()
                            Text(FormattingUtils.formatCurrency(billNeeds))
                                .foregroundStyle(.blue)
                        }
                        
                        HStack {
                            Text("Bills (Wants)")
                            Spacer()
                            Text(FormattingUtils.formatCurrency(billWants))
                                .foregroundStyle(.orange)
                        }
                        
                        Divider()
                        
                        // Transactions (One-time Expenses)
                        HStack {
                            Text("One-time Expenses")
                                .font(.headline)
                            Spacer()
                        }
                        
                        let transactionNeeds = spending.needs - billNeeds
                        let transactionWants = spending.wants - billWants
                        
                        HStack {
                            Text("Transactions (Needs)")
                            Spacer()
                            Text(FormattingUtils.formatCurrency(transactionNeeds))
                                .foregroundStyle(.blue)
                        }
                        
                        HStack {
                            Text("Transactions (Wants)")
                            Spacer()
                            Text(FormattingUtils.formatCurrency(transactionWants))
                                .foregroundStyle(.orange)
                        }
                        
                        HStack {
                            Text("Not Accounted")
                            Spacer()
                            Text(FormattingUtils.formatCurrency(spending.notAccounted))
                                .foregroundStyle(.gray)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Monthly Savings")
                                .bold()
                            Spacer()
                            Text(FormattingUtils.formatCurrency(monthlySavings))
                                .bold()
                                .foregroundStyle(.green)
                        }
                    }
                    
                    Section {
                        Button("Next: Classify Categories") {
                            withAnimation {
                                currentStep = 4
                            }
                        }
                    }
                }
                
                // Step 4: Category Classification
                if currentStep == 4 {
                    Section {
                        Button("Auto-Classify Categories") {
                            showingAutoClassifyAlert = true
                        }
                    }
                    
                    Section("Bill Categories") {
                        ForEach(Array(BillCategory.allCases), id: \.self) { category in
                            Picker(category.rawValue, selection: Binding(
                                get: { billCategoryTypes[category.rawValue] ?? .other },
                                set: { billCategoryTypes[category.rawValue] = $0 }
                            )) {
                                Text("Need").tag(ExpenseType.need)
                                Text("Want").tag(ExpenseType.want)
                                Text("Not Accounted").tag(ExpenseType.other)
                            }
                        }
                    }
                    
                    Section("Transaction Categories") {
                        ForEach(Array(TransactionCategory.allCases), id: \.self) { category in
                            Picker(category.rawValue, selection: Binding(
                                get: { transactionCategoryTypes[category.rawValue] ?? .other },
                                set: { transactionCategoryTypes[category.rawValue] = $0 }
                            )) {
                                Text("Need").tag(ExpenseType.need)
                                Text("Want").tag(ExpenseType.want)
                                Text("Not Accounted").tag(ExpenseType.other)
                            }
                        }
                    }
                    
                    Section {
                        Button("Next: Review Savings Plan") {
                            withAnimation {
                                currentStep = 5
                            }
                        }
                    }
                }
                
                // Step 5: Savings Plan
                if currentStep == 5 {
                    Section("Required Monthly Savings") {
                        HStack {
                            Text("Target Amount")
                            Spacer()
                            Text(FormattingUtils.formatCurrency(goal.targetAmount ?? 0))
                        }
                        
                        HStack {
                            Text("Current Amount")
                            Spacer()
                            Text(FormattingUtils.formatCurrency(goal.currentAmount))
                        }
                        
                        HStack {
                            Text("Required Monthly Savings")
                            Spacer()
                            Text(FormattingUtils.formatCurrency(requiredMonthlySavings))
                                .foregroundStyle(.green)
                        }
                    }
                    
                    Section("Current Monthly Savings") {
                        HStack {
                            Text("Monthly Income")
                            Spacer()
                            Text(FormattingUtils.formatCurrency(monthlyIncome))
                        }
                        
                        HStack {
                            Text("Total Expenses")
                            Spacer()
                            Text(FormattingUtils.formatCurrency(spending.needs + spending.wants + spending.notAccounted))
                        }
                        
                        HStack {
                            Text("Current Monthly Savings")
                            Spacer()
                            Text(FormattingUtils.formatCurrency(monthlySavings))
                                .foregroundStyle(.green)
                        }
                    }
                    
                    if monthlySavings < requiredMonthlySavings {
                        Section("Adjustment Needed") {
                            Text("You need to save \(FormattingUtils.formatCurrency(requiredMonthlySavings - monthlySavings)) more per month to reach your goal.")
                                .foregroundStyle(.red)
                        }
                    }
                    
                    Section {
                        Button("Save Goal") {
                            saveGoal()
                        }
                        .disabled(name.isEmpty || selectedIncomes.isEmpty)
                    }
                }
            }
            .navigationTitle("New Financial Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Auto-Classify Categories", isPresented: $showingAutoClassifyAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Auto-Classify") {
                    autoClassifyCategories()
                }
            } message: {
                Text("This will automatically classify your categories based on common budgeting practices. You can still adjust them manually afterward.")
            }
        }
    }
    
    private func autoClassifyCategories() {
        // Common needs categories
        let needsCategories: Set<String> = [
            "Housing", "Utilities", "Groceries", "Healthcare",
            "Insurance", "Transportation", "Education"
        ]
        
        // Common wants categories
        let wantsCategories: Set<String> = [
            "Entertainment", "Dining Out", "Shopping",
            "Travel", "Hobbies", "Fitness"
        ]
        
        // Classify bill categories
        for category in BillCategory.allCases {
            if needsCategories.contains(category.rawValue) {
                billCategoryTypes[category.rawValue] = .need
            } else if wantsCategories.contains(category.rawValue) {
                billCategoryTypes[category.rawValue] = .want
            } else {
                billCategoryTypes[category.rawValue] = .other
            }
        }
        
        // Classify transaction categories
        for category in TransactionCategory.allCases {
            if needsCategories.contains(category.rawValue) {
                transactionCategoryTypes[category.rawValue] = .need
            } else if wantsCategories.contains(category.rawValue) {
                transactionCategoryTypes[category.rawValue] = .want
            } else {
                transactionCategoryTypes[category.rawValue] = .other
            }
        }
    }
    
    private func getCategoryType(for category: String, isBill: Bool) -> ExpenseType {
        goal.getCategoryType(for: category, isBill: isBill)
    }
    
    private func saveGoal() {
        guard let user = users.first else {
            print("Error: No user found")
            return
        }
        
        do {
            goal.name = name
            goal.targetAmount = FormattingUtils.parseNumber(targetAmount)
            goal.targetDate = targetDate
            
            // Save category types
            var billTypes: [String: String] = [:]
            for (category, type) in billCategoryTypes {
                billTypes[category] = type.rawValue
            }
            goal.billCategoryTypes = billTypes
            
            var transactionTypes: [String: String] = [:]
            for (category, type) in transactionCategoryTypes {
                transactionTypes[category] = type.rawValue
            }
            goal.transactionCategoryTypes = transactionTypes
            
            // Set up the relationship
            goal.user = user
            if user.financialGoals == nil {
                user.financialGoals = []
            }
            user.financialGoals?.append(goal)
            
            // Insert the goal into the model context
            modelContext.insert(goal)
            
            // Save changes
            try modelContext.save()
            
            // Save secure data
            Task {
                try? await goal.saveSecureData()
            }
            
            dismiss()
        } catch {
            print("Error saving goal: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        FinancialGoalsView()
    }
    .modelContainer(PreviewData.createPreviewContainer())
}

extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
} 
