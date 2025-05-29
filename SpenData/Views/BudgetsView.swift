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
    @Environment(\.dismiss) private var dismiss
    let bill: Bill
    
    @State private var showingEditSheet = false
    @State private var showingPaidBills = false
    
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
            DetailItem(label: "Recurrence", value: bill.recurrence ?? "One-time"),
            DetailItem(label: "Shared", value: bill.isShared ? "Yes (\(bill.numberOfShares) people)" : "No")
        ]
    }
    
    private func generateUpcomingOccurrences() -> [Date] {
        guard let recurrence = bill.recurrence,
              let recurrenceEnum = BillRecurrence(rawValue: recurrence) else {
            return [bill.firstInstallment]
        }
        
        var occurrences: [Date] = []
        var currentDate = bill.firstInstallment
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        while currentDate <= endDate {
            occurrences.append(currentDate)
            currentDate = recurrenceEnum.nextDueDate(from: currentDate)
        }
        
        return occurrences
    }
    
    var body: some View {
        List {
            Section("Details") {
                ForEach(details) { detail in
                    HStack {
                        Text(detail.label)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(detail.value)
                    }
                }
            }
            
            Section("Upcoming Occurrences") {
                ForEach(generateUpcomingOccurrences(), id: \.self) { date in
                    HStack {
                        Text(date.formatted(date: .long, time: .omitted))
                        Spacer()
                        Text(FormattingUtils.formatCurrency(bill.amount / Double(bill.isShared ? bill.numberOfShares : 1)))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section {
                Button("View Paid Bills") {
                    showingPaidBills = true
                }
            }
        }
        .navigationTitle(bill.name ?? "Bill Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditBillView(bill: bill)
        }
        .sheet(isPresented: $showingPaidBills) {
            PaidBillsView(bill: bill)
        }
    }
}

struct EditBillView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let bill: Bill
    
    @State private var name: String
    @State private var amount: String
    @State private var category: BillCategory
    @State private var issuer: String
    @State private var firstInstallment: Date
    @State private var recurrence: BillRecurrence
    @State private var isShared: Bool
    @State private var numberOfShares: Int
    
    init(bill: Bill) {
        self.bill = bill
        _name = State(initialValue: bill.name ?? "")
        _amount = State(initialValue: String(bill.amount))
        _category = State(initialValue: BillCategory(rawValue: bill.category ?? "") ?? .uncategorized)
        _issuer = State(initialValue: bill.issuer ?? "")
        _firstInstallment = State(initialValue: bill.firstInstallment)
        _recurrence = State(initialValue: BillRecurrence(rawValue: bill.recurrence ?? "") ?? .monthly)
        _isShared = State(initialValue: bill.isShared)
        _numberOfShares = State(initialValue: bill.numberOfShares)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Bill Details") {
                    TextField("Name", text: $name)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(BillCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    TextField("Issuer", text: $issuer)
                    DatePicker("First Installment", selection: $firstInstallment, displayedComponents: .date)
                    Picker("Recurrence", selection: $recurrence) {
                        ForEach(BillRecurrence.allCases, id: \.self) { recurrence in
                            Text(recurrence.rawValue).tag(recurrence)
                        }
                    }
                }
                
                Section {
                    Toggle("Shared Bill", isOn: $isShared)
                    if isShared {
                        Stepper("Number of Shares: \(numberOfShares)", value: $numberOfShares, in: 2...10)
                    }
                }
            }
            .navigationTitle("Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBill()
                    }
                }
            }
        }
    }
    
    private func saveBill() {
        if let amountValue = Double(amount) {
            bill.name = name
            bill.amount = amountValue
            bill.category = category.rawValue
            bill.issuer = issuer
            bill.firstInstallment = firstInstallment
            bill.recurrence = recurrence.rawValue
            bill.isShared = isShared
            bill.numberOfShares = numberOfShares
            
            try? modelContext.save()
            dismiss()
        }
    }
}

struct PaidBillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let bill: Bill
    @Query private var paidBills: [Bill]
    
    init(bill: Bill) {
        self.bill = bill
        let predicate = #Predicate<Bill> { paidBill in
            paidBill.isPaid == true
        }
        _paidBills = Query(filter: predicate)
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(paidBills.filter { $0.name == bill.name && $0.issuer == bill.issuer }) { paidBill in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(paidBill.firstInstallment.formatted(date: .long, time: .omitted))
                                .font(.headline)
                            Spacer()
                            Text(FormattingUtils.formatCurrency(paidBill.amount / Double(paidBill.isShared ? paidBill.numberOfShares : 1)))
                                .font(.headline)
                        }
                        
                        if paidBill.isShared {
                            Text("Shared: \(paidBill.numberOfShares) people")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Paid Bills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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
                
                let existingBill = bills.first(where: { existingBill in
                    existingBill.name == bill.name &&
                    existingBill.firstInstallment >= startOfMonth &&
                    existingBill.firstInstallment < endOfMonth
                })
                
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
        
        // Create a dictionary to track unique bills by their name, issuer, and category
        var uniqueBills: [String: Bill] = [:]
        
        // Filter bills for the current month and deduplicate
        for bill in bills where bill.firstInstallment >= startOfMonth && bill.firstInstallment < endOfMonth {
            let key = "\(bill.name ?? "")-\(bill.issuer ?? "")-\(bill.category ?? "")"
            if uniqueBills[key] == nil {
                uniqueBills[key] = bill
            }
        }
        
        // Group the unique bills by category
        return Dictionary(grouping: Array(uniqueBills.values)) { $0.category ?? "Uncategorized" }
    }
    
    private func calculateTotalForBills(_ bills: [Bill]) -> Double {
        bills.reduce(0) { total, bill in
            let billAmount = bill.amount ?? 0
            let userShare = bill.isShared ? billAmount / Double(bill.numberOfShares) : billAmount
            return total + userShare
        }
    }
    
    private func calculateSpentAmount(for budget: TransactionBudget) -> Double {
        guard let category = budget.category else { return 0 }
        
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        return transactions
            .filter { $0.category == category && $0.date >= startOfMonth && $0.date < endOfMonth }
            .reduce(0) { $0 + abs($1.amount) }
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
            // Always show budgets that have a limit set
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
                        let total = calculateTotalForBills(bills)
                        
                        NavigationLink(destination: CategoryBillsView(category: category)) {
                            HStack {
                                Circle()
                                    .fill(BillCategory(rawValue: category)?.color ?? .gray)
                                    .frame(width: 12, height: 12)
                                VStack(alignment: .leading) {
                                    Text(category)
                                        .font(.headline)
                                    Text("\(bills.count) bills")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(FormattingUtils.formatCurrency(total))
                                    .font(.headline)
                            }
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
            .navigationTitle("Budgets")
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
