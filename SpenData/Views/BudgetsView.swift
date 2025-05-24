import SwiftUI
import SwiftData
import Charts

struct BudgetProgressView: View {
    let spent: Double
    let total: Double
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return min(spent / total, 1.0)
    }
    
    var body: some View {
        ProgressView(value: progress)
            .tint(progress > 1.0 ? .red : .blue)
    }
}

struct BillDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let bill: Bill
    
    private struct DetailItem: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }
    
    private var details: [DetailItem] {
        [
            DetailItem(label: "Name", value: bill.name ?? "Unnamed"),
            DetailItem(label: "Amount", value: FormattingUtils.formatCurrency(bill.amount ?? 0)),
            DetailItem(label: "Category", value: bill.category ?? "Uncategorized"),
            DetailItem(label: "Issuer", value: bill.issuer ?? "Unknown"),
            DetailItem(label: "Due Date", value: bill.firstInstallment.formatted(date: .long, time: .omitted)),
            DetailItem(label: "Recurrence", value: bill.recurrence ?? "One-time")
        ]
    }
    
    var body: some View {
        List {
            Section {
                ForEach(details) { item in
                    LabeledContent(item.label, value: item.value)
                }
            } header: {
                Text("Details")
            }
            
            Section {
                Button(action: {
                    bill.isPaid.toggle()
                    try? modelContext.save()
                }) {
                    HStack {
                        Image(systemName: bill.isPaid ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(bill.isPaid ? .green : .gray)
                        Text(bill.isPaid ? "Mark as Unpaid" : "Mark as Paid")
                            .foregroundColor(bill.isPaid ? .green : .primary)
                    }
                }
            } header: {
                Text("Payment Status")
            }
        }
        .navigationTitle(bill.name ?? "Bill Details")
    }
}

struct CategoryTransactionsView: View {
    let category: String
    let transactions: [Transaction]
    
    var body: some View {
        List {
            ForEach(transactions) { transaction in
                HStack {
                    VStack(alignment: .leading) {
                        Text(transaction.name ?? "Unnamed")
                            .font(.headline)
                        Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(FormattingUtils.formatCurrency(transaction.amount))
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle(category)
    }
}

struct BudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var billBudgets: [BillBudget]
    @Query private var bills: [Bill]
    @Query private var transactionBudgets: [TransactionBudget]
    @Query private var transactions: [Transaction]
    
    @State private var selectedMonth = Date()
    @State private var showingAddBudget = false
    
    private var monthString: String {
        selectedMonth.formatted(.dateTime.month().year())
    }
    
    private func handleBillRecurrence() {
        let calendar = Calendar.current
        // Set the upper bound to the end of the selected month
        let startOfSelectedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfSelectedMonth = calendar.date(byAdding: .month, value: 1, to: startOfSelectedMonth)!
        
        // Get all bills that have recurrence
        let recurringBills = bills.filter { bill in
            guard let recurrence = bill.recurrence,
                  let recurrenceEnum = BillRecurrence(rawValue: recurrence) else {
                return false
            }
            return recurrenceEnum != .custom
        }
        
        for bill in recurringBills {
            guard let recurrence = bill.recurrence,
                  let recurrenceEnum = BillRecurrence(rawValue: recurrence) else {
                continue
            }
            
            // Start from the first installment date
            var currentDate = bill.firstInstallment
            
            // Keep creating new instances until we reach the end of the selected month
            while currentDate < endOfSelectedMonth {
                // Calculate the next due date
                let nextDueDate = recurrenceEnum.nextDueDate(from: currentDate)
                
                // Check if a bill for this period already exists
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextDueDate))!
                let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
                
                let existingBill = bills.first { existingBill in
                    existingBill.name == bill.name &&
                    existingBill.firstInstallment >= startOfMonth &&
                    existingBill.firstInstallment < endOfMonth
                }
                
                if existingBill == nil {
                    // Create new bill instance
                    let newBill = Bill(
                        name: bill.name ?? "Unnamed Bill",
                        amount: bill.amount,
                        category: bill.category ?? BillCategory.uncategorized.rawValue,
                        issuer: bill.issuer ?? "Unknown",
                        firstInstallment: nextDueDate,
                        recurrence: bill.recurrence ?? BillRecurrence.monthly.rawValue,
                        isShared: bill.isShared,
                        numberOfShares: bill.numberOfShares
                    )
                    
                    modelContext.insert(newBill)
                }
                
                // Move to the next period
                currentDate = nextDueDate
            }
        }
        
        // Save changes
        try? modelContext.save()
    }
    
    private var billsByCategory: [String: [Bill]] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        return Dictionary(grouping: bills.filter { bill in
            bill.firstInstallment >= startOfMonth && bill.firstInstallment < endOfMonth
        }) { $0.category ?? "Uncategorized" }
    }
    
    private func calculateSpentAmount(for budget: TransactionBudget) -> Double {
        guard let category = budget.category else { return 0 }
        
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        return transactions
            .filter { $0.category == category && $0.date >= startOfMonth && $0.date < endOfMonth }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var filteredTransactionBudgets: [TransactionBudget] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        // Get all categories that have transactions this month
        let activeCategories = Set(transactions
            .filter { $0.date >= startOfMonth && $0.date < endOfMonth }
            .compactMap { $0.category })
        
        return transactionBudgets.filter { budget in
            // Keep all budgets that have a limit set
            if let limit = budget.limit, limit > 0 {
                return true
            }
            // For budgets without limits, only show if there are transactions this month
            return activeCategories.contains(budget.category ?? "")
        }
    }
    
    private func transactionsForCategory(_ category: String) -> [Transaction] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        return transactions
            .filter { $0.category == category && $0.date >= startOfMonth && $0.date < endOfMonth }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Month selector
                HStack {
                    Button(action: { selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth)! }) {
                        Image(systemName: "chevron.left")
                    }
                    
                    Text(monthString)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    
                    Button(action: { selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth)! }) {
                        Image(systemName: "chevron.right")
                    }
                }
                .padding(.horizontal)
                
                // Bills List
                List {
                    ForEach(Array(billsByCategory.keys.sorted()), id: \.self) { category in
                        let bills = billsByCategory[category] ?? []
                        Section {
                            ForEach(bills) { bill in
                                NavigationLink(destination: BillDetailView(bill: bill)) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(bill.name ?? "Unnamed Bill")
                                                .font(.headline)
                                            Text(FormattingUtils.formatCurrency(bill.amount ?? 0))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing) {
                                            Text(bill.firstInstallment.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            if let budget = billBudgets.first(where: { $0.category == category }) {
                                                Toggle("Paid", isOn: Binding(
                                                    get: { budget.isPaid },
                                                    set: { newValue in
                                                        budget.isPaid = newValue
                                                        try? modelContext.save()
                                                    }
                                                ))
                                                .labelsHidden()
                                            }
                                        }
                                    }
                                    .opacity(bill.isPaid ? 0.6 : 1.0)
                                }
                            }
                        } header: {
                            Text(category)
                        }
                    }
                    // Transaction Budgets Section
                    if !filteredTransactionBudgets.isEmpty {
                        Section(header: Text("Category Budgets")) {
                            ForEach(filteredTransactionBudgets) { budget in
                                NavigationLink(destination: CategoryTransactionsView(
                                    category: budget.category ?? "Uncategorized",
                                    transactions: transactionsForCategory(budget.category ?? "")
                                )) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(budget.category ?? "Uncategorized")
                                                .font(.headline)
                                            Spacer()
                                            if let limit = budget.limit, limit > 0 {
                                                Text(FormattingUtils.formatCurrency(limit))
                                                    .font(.subheadline)
                                            } else {
                                                let spent = calculateSpentAmount(for: budget)
                                                Text(FormattingUtils.formatCurrency(spent))
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        if let limit = budget.limit, limit > 0 {
                                            let spent = calculateSpentAmount(for: budget)
                                            ProgressView(value: min(spent/limit, 1.0))
                                                .tint(spent > limit ? .red : .blue)
                                            HStack {
                                                Text("Spent: \(FormattingUtils.formatCurrency(spent))")
                                                Spacer()
                                                Text("Remaining: \(FormattingUtils.formatCurrency(max(limit - spent, 0)))")
                                            }
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        }
                                        if let period = budget.period {
                                            Text(period)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bills")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddBudget = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBudget) {
                AddTransactionBudgetView()
            }
            .onAppear {
                handleBillRecurrence()
            }
        }
    }
}

#Preview {
    BudgetsView()
        .modelContainer(PreviewData.createPreviewContainer())
} 
