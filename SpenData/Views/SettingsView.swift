import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                if let user = users.first {
                    Section {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(user.name ?? "Not set")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email ?? "Not set")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Device ID")
                            Spacer()
                            Text(user.deviceIdentifier)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    NavigationLink(destination: BillsListView()) {
                        Label("Bills", systemImage: "list.bullet")
                    }
                    
                    NavigationLink(destination: TransactionBudgetsListView()) {
                        Label("Transaction Budgets", systemImage: "dollarsign.circle")
                    }
                    
                    NavigationLink(destination: IncomeSourcesListView()) {
                        Label("Income Sources", systemImage: "dollarsign.square")
                    }
                    
                    NavigationLink(destination: FinancialGoalsView()) {
                        Label("Financial Goals", systemImage: "target")
                    }
                    
                    NavigationLink(destination: CategoriesView()) {
                        Label("Categories", systemImage: "tag")
                    }
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        showingSignOutConfirmation = true
                    }
                }
                
                Section {
                    Button("Delete Account", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
            .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
        .task {
            if let user = users.first {
                do {
                    try await user.loadSecureData()
                    try modelContext.save()
                } catch {
                    print("Error loading user data: \(error)")
                }
            }
        }
    }
    
    private func deleteAccount() {
        guard let user = users.first else { return }
        
        // Delete all bills
        if let bills = user.bills {
            for bill in bills {
                modelContext.delete(bill)
            }
        }
        
        // Delete user
        modelContext.delete(user)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error deleting account: \(error)")
        }
    }
    
    private func signOut() {
        guard let user = users.first else { return }
        
        // Update last login date
        user.updateLastLoginDate()
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}

struct BillsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bills: [Bill]
    @State private var showingAddBill = false
    
    private struct UniqueBill: Identifiable, Hashable {
        let id: String
        let name: String
        let amount: Double
        let category: String
        let issuer: String
        let firstInstallment: Date
        let recurrence: String
        let isShared: Bool
        let numberOfShares: Int
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(issuer)
            hasher.combine(category)
        }
        
        static func == (lhs: UniqueBill, rhs: UniqueBill) -> Bool {
            lhs.name == rhs.name && lhs.issuer == rhs.issuer && lhs.category == rhs.category
        }
    }
    
    private var uniqueBills: [UniqueBill] {
        let uniqueBills = Set(bills.map { bill in
            UniqueBill(
                id: bill.id ?? UUID().uuidString,
                name: bill.name ?? "",
                amount: bill.amount,
                category: bill.category ?? "Uncategorized",
                issuer: bill.issuer ?? "",
                firstInstallment: bill.firstInstallment,
                recurrence: bill.recurrence ?? "",
                isShared: bill.isShared,
                numberOfShares: bill.numberOfShares
            )
        })
        return Array(uniqueBills)
    }
    
    private var billsByCategory: [String: [UniqueBill]] {
        Dictionary(grouping: uniqueBills) { $0.category }
    }
    
    private func calculateMonthlyAmount(for bill: UniqueBill) -> Double {
        let baseAmount = bill.amount / Double(bill.isShared ? bill.numberOfShares : 1)
        guard let recurrenceEnum = BillRecurrence(rawValue: bill.recurrence) else {
            return baseAmount
        }
        
        switch recurrenceEnum {
        case .monthly:
            return baseAmount
        case .quarterly:
            return baseAmount / 3
        case .yearly:
            return baseAmount / 12
        case .custom:
            return baseAmount // For custom, we'll assume monthly for now
        }
    }
    
    var body: some View {
        List {
            ForEach(Array(billsByCategory.keys.sorted()), id: \.self) { category in
                NavigationLink(destination: CategoryBillsView(category: category)) {
                    HStack {
                        Circle()
                            .fill(BillCategory(rawValue: category)?.color ?? .gray)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading) {
                            Text(category)
                                .font(.headline)
                            Text("\(billsByCategory[category]?.count ?? 0) bills")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let bills = billsByCategory[category] {
                            let total = bills.reduce(0) { $0 + calculateMonthlyAmount(for: $1) }
                            Text(FormattingUtils.formatCurrency(total))
                                .font(.headline)
                        }
                    }
                }
            }
        }
        .navigationTitle("Bills")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddBill = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddBill) {
            AddBillView()
        }
    }
}

struct CategoryBillsView: View {
    let category: String
    @Query private var bills: [Bill]
    @Environment(\.modelContext) private var modelContext
    
    private struct UniqueBill: Identifiable, Hashable {
        let id: String
        let name: String
        let amount: Double
        let category: String
        let issuer: String
        let firstInstallment: Date
        let recurrence: String
        let isShared: Bool
        let numberOfShares: Int
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(issuer)
            hasher.combine(category)
        }
        
        static func == (lhs: UniqueBill, rhs: UniqueBill) -> Bool {
            lhs.name == rhs.name && lhs.issuer == rhs.issuer && lhs.category == rhs.category
        }
    }
    
    init(category: String) {
        self.category = category
        let predicate = #Predicate<Bill> { bill in
            bill.category == category
        }
        _bills = Query(filter: predicate)
    }
    
    private var uniqueBills: [UniqueBill] {
        let uniqueBills = Set(bills.map { bill in
            UniqueBill(
                id: bill.id ?? UUID().uuidString,
                name: bill.name ?? "",
                amount: bill.amount,
                category: bill.category ?? "Uncategorized",
                issuer: bill.issuer ?? "",
                firstInstallment: bill.firstInstallment,
                recurrence: bill.recurrence ?? "",
                isShared: bill.isShared,
                numberOfShares: bill.numberOfShares
            )
        })
        return Array(uniqueBills)
    }
    
    private func calculateMonthlyAmount(for bill: UniqueBill) -> Double {
        let baseAmount = bill.amount / Double(bill.isShared ? bill.numberOfShares : 1)
        guard let recurrenceEnum = BillRecurrence(rawValue: bill.recurrence) else {
            return baseAmount
        }
        
        switch recurrenceEnum {
        case .monthly:
            return baseAmount
        case .quarterly:
            return baseAmount / 3
        case .yearly:
            return baseAmount / 12
        case .custom:
            return baseAmount // For custom, we'll assume monthly for now
        }
    }
    
    private func findOriginalBill(for uniqueBill: UniqueBill) -> Bill? {
        bills.first { bill in
            bill.name == uniqueBill.name &&
            bill.issuer == uniqueBill.issuer &&
            bill.category == uniqueBill.category
        }
    }
    
    var body: some View {
        List {
            ForEach(uniqueBills) { uniqueBill in
                if let originalBill = findOriginalBill(for: uniqueBill) {
                    NavigationLink(destination: BillDetailView(bill: originalBill)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(uniqueBill.name)
                                    .font(.headline)
                                Spacer()
                                Text(FormattingUtils.formatCurrency(calculateMonthlyAmount(for: uniqueBill)))
                                    .font(.headline)
                            }
                            
                            HStack {
                                Text(uniqueBill.issuer)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Next due: \(uniqueBill.firstInstallment, style: .date)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if uniqueBill.isShared {
                                Text("Shared: \(uniqueBill.numberOfShares) people")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if !uniqueBill.recurrence.isEmpty {
                                Text("Recurrence: \(uniqueBill.recurrence)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .onDelete(perform: deleteBills)
        }
        .navigationTitle(category)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
    
    private func deleteBills(at offsets: IndexSet) {
        for index in offsets {
            let uniqueBill = uniqueBills[index]
            // Delete all instances of this bill
            let billsToDelete = bills.filter { bill in
                bill.name == uniqueBill.name &&
                bill.issuer == uniqueBill.issuer &&
                bill.category == uniqueBill.category
            }
            for bill in billsToDelete {
                modelContext.delete(bill)
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting bills: \(error)")
        }
    }
}

struct TransactionBudgetsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactionBudgets: [TransactionBudget]
    @State private var showingAddBudget = false
    @State private var showingEditBudget = false
    @State private var selectedBudget: TransactionBudget?
    
    private var explicitBudgets: [TransactionBudget] {
        transactionBudgets.filter { budget in
            guard let limit = budget.limit else { return false }
            return limit > 0
        }
    }
    
    var body: some View {
        List {
            ForEach(explicitBudgets) { budget in
                Button {
                    selectedBudget = budget
                    showingEditBudget = true
                } label: {
                    HStack {
                        Circle()
                            .fill(TransactionCategory(rawValue: budget.category ?? "")?.color ?? .gray)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading) {
                            Text(budget.category ?? "Uncategorized")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if let period = budget.period {
                                Text(period)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let limit = budget.limit {
                            Text(FormattingUtils.formatCurrency(limit))
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: deleteBudgets)
        }
        .navigationTitle("Transaction Budgets")
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
        .sheet(isPresented: $showingEditBudget) {
            if let budget = selectedBudget {
                EditTransactionBudgetView(budget: budget)
            }
        }
    }
    
    private func deleteBudgets(at offsets: IndexSet) {
        for index in offsets {
            let budget = explicitBudgets[index]
            modelContext.delete(budget)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting budgets: \(error)")
        }
    }
}

struct EditTransactionBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let budget: TransactionBudget
    
    @State private var category: String
    @State private var limit: String
    @State private var period: BudgetPeriod
    
    init(budget: TransactionBudget) {
        self.budget = budget
        _category = State(initialValue: budget.category ?? TransactionCategory.uncategorized.rawValue)
        _limit = State(initialValue: String(budget.limit ?? 0))
        _period = State(initialValue: BudgetPeriod(rawValue: budget.period ?? "") ?? .monthly)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(TransactionCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category.rawValue)
                    }
                }
                
                TextField("Limit", text: $limit)
                    .keyboardType(.decimalPad)
                
                Picker("Period", selection: $period) {
                    Text("Weekly").tag(BudgetPeriod.weekly)
                    Text("Monthly").tag(BudgetPeriod.monthly)
                    Text("Yearly").tag(BudgetPeriod.yearly)
                }
            }
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBudget()
                    }
                }
            }
        }
    }
    
    private func saveBudget() {
        if let limitValue = FormattingUtils.parseNumber(limit) {
            budget.category = category
            budget.limit = limitValue
            budget.period = period.rawValue
            
            try? modelContext.save()
            dismiss()
        }
    }
}

struct IncomeSourcesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var incomes: [Income]
    @State private var showingAddIncome = false
    
    private var incomesByCategory: [String: [Income]] {
        Dictionary(grouping: incomes) { $0.category ?? "Uncategorized" }
    }
    
    var body: some View {
        List {
            ForEach(Array(incomesByCategory.keys.sorted()), id: \.self) { category in
                NavigationLink(destination: CategoryIncomesView(category: category)) {
                    HStack {
                        Circle()
                            .fill(IncomeCategory(rawValue: category)?.color ?? .gray)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading) {
                            Text(category)
                                .font(.headline)
                            Text("\(incomesByCategory[category]?.count ?? 0) sources")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let total = incomesByCategory[category]?.reduce(0, { $0 + $1.amount }) {
                            Text(FormattingUtils.formatCurrency(total))
                                .font(.headline)
                        }
                    }
                }
            }
        }
        .navigationTitle("Income Sources")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddIncome = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddIncome) {
            AddIncomeView()
        }
    }
}

struct CategoryIncomesView: View {
    let category: String
    @Query private var incomes: [Income]
    @Environment(\.modelContext) private var modelContext
    
    init(category: String) {
        self.category = category
        let predicate = #Predicate<Income> { income in
            income.category == category
        }
        _incomes = Query(filter: predicate)
    }
    
    var body: some View {
        List {
            ForEach(incomes) { income in
                NavigationLink(destination: IncomeDetailView(income: income)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(income.name ?? "Unnamed Income")
                                .font(.headline)
                            Spacer()
                            Text(FormattingUtils.formatCurrency(income.amount))
                                .font(.headline)
                        }
                        
                        HStack {
                            Text(income.issuer ?? "Unknown Issuer")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Next payment: \(income.firstPayment, style: .date)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let frequency = income.frequency {
                            Text("Frequency: \(frequency)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteIncomes)
        }
        .navigationTitle(category)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
    
    private func deleteIncomes(at offsets: IndexSet) {
        for index in offsets {
            let income = incomes[index]
            modelContext.delete(income)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting incomes: \(error)")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [User.self, Bill.self])
} 