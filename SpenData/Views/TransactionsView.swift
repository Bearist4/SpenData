import SwiftUI
import SwiftData
import Charts

enum TimePeriod: String, CaseIterable {
    case day = "D"
    case week = "W"
    case month = "M"
    case quarter = "Q"
    case sixMonths = "6M"
    case year = "Y"
    
    func dateRange(from date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        switch self {
        case .day:
            return (startOfDay, calendar.date(byAdding: .day, value: 1, to: startOfDay)!)
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfDay))!
            return (startOfWeek, calendar.date(byAdding: .day, value: 7, to: startOfWeek)!)
        case .month:
            let components = calendar.dateComponents([.year, .month], from: startOfDay)
            let startOfMonth = calendar.date(from: components)!
            return (startOfMonth, calendar.date(byAdding: .month, value: 1, to: startOfMonth)!)
        case .quarter:
            let components = calendar.dateComponents([.year, .month], from: startOfDay)
            let startOfMonth = calendar.date(from: components)!
            let quarter = (components.month! - 1) / 3
            let startOfQuarter = calendar.date(byAdding: .month, value: quarter * 3, to: startOfMonth)!
            return (startOfQuarter, calendar.date(byAdding: .month, value: 3, to: startOfQuarter)!)
        case .sixMonths:
            let components = calendar.dateComponents([.year, .month], from: startOfDay)
            let startOfMonth = calendar.date(from: components)!
            let halfYear = (components.month! - 1) / 6
            let startOfHalfYear = calendar.date(byAdding: .month, value: halfYear * 6, to: startOfMonth)!
            return (startOfHalfYear, calendar.date(byAdding: .month, value: 6, to: startOfHalfYear)!)
        case .year:
            let components = calendar.dateComponents([.year], from: startOfDay)
            let startOfYear = calendar.date(from: components)!
            return (startOfYear, calendar.date(byAdding: .year, value: 1, to: startOfYear)!)
        }
    }
}

struct TransactionChartView: View {
    let transactions: [Transaction]
    let timePeriod: TimePeriod
    
    private var dailyAmounts: [(date: Date, amount: Double)] {
        let calendar = Calendar.current
        let (startDate, endDate) = timePeriod.dateRange(from: Date())
        
        let filteredTransactions = transactions.filter { transaction in
            transaction.date >= startDate && transaction.date < endDate
        }
        
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        
        return grouped.map { (date, transactions) in
            let total = transactions.reduce(0) { $0 + $1.amount }
            return (date: date, amount: total)
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        Chart(dailyAmounts, id: \.date) { item in
            BarMark(
                x: .value("Date", item.date),
                y: .value("Amount", abs(item.amount))
            )
            .foregroundStyle(.red)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel(format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
            }
        }
        .frame(height: 200)
        .padding()
    }
}

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @State private var selectedTimePeriod: TimePeriod = .month
    @State private var viewMode: ViewMode = .daily
    @State private var showingAddTransaction = false
    
    enum ViewMode: String, CaseIterable {
        case daily = "Daily"
        case category = "Category"
    }
    
    private var groupedTransactions: [(Date, [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    private var categorySummaries: [(category: String, amount: Double, count: Int)] {
        let grouped = Dictionary(grouping: transactions) { $0.category ?? TransactionCategory.uncategorized.rawValue }
        return grouped.map { (category, transactions) in
            let totalAmount = transactions.reduce(0) { $0 + abs($1.amount) }
            return (category: category, amount: totalAmount, count: transactions.count)
        }.sorted { $0.amount > $1.amount }
    }
    
    private var categoryTotals: [(category: String, amount: Double)] {
        let grouped = Dictionary(grouping: transactions) { $0.category ?? TransactionCategory.uncategorized.rawValue }
        return grouped.map { (category, transactions) in
            let total = transactions.reduce(0) { $0 + abs($1.amount) }
            return (category: category, amount: total)
        }.sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Time Period", selection: $selectedTimePeriod) {
                            ForEach(TimePeriod.allCases, id: \.self) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if viewMode == .daily {
                            TransactionChartView(transactions: transactions, timePeriod: selectedTimePeriod)
                        } else {
                            TransactionCategoryChartView(categoryTotals: categoryTotals)
                        }
                    }
                }
                
                Section {
                    Picker("View Mode", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }
                
                if viewMode == .category {
                    Section("Categories") {
                        ForEach(categorySummaries, id: \.category) { summary in
                            NavigationLink(destination: TransactionCategoryDetailView(category: summary.category)) {
                                HStack {
                                    Circle()
                                        .fill(TransactionCategory(rawValue: summary.category)?.color ?? .gray)
                                        .frame(width: 12, height: 12)
                                    VStack(alignment: .leading) {
                                        Text(summary.category)
                                            .font(.headline)
                                        Text("\(summary.count) transactions")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(FormattingUtils.formatCurrency(summary.amount))
                                        .font(.headline)
                                }
                            }
                        }
                    }
                }
                
                if viewMode == .daily {
                    ForEach(groupedTransactions, id: \.0) { date, transactions in
                        Section(header: Text(date.formatted(date: .complete, time: .omitted))) {
                            ForEach(transactions) { transaction in
                                NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                    TransactionListItem(transaction: transaction)
                                }
                            }
                            .onDelete { indexSet in
                                deleteTransactions(at: indexSet, in: transactions)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTransaction = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }
        }
    }
    
    private func deleteTransactions(at offsets: IndexSet, in transactions: [Transaction]) {
        for index in offsets {
            let transaction = transactions[index]
            modelContext.delete(transaction)
        }
    }
}

struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Amount")
                    Spacer()
                    Text(FormattingUtils.formatCurrency(abs(transaction.amount)))
                }
                
                HStack {
                    Text("Category")
                    Spacer()
                    Text(transaction.category ?? "Uncategorized")
                }
                
                HStack {
                    Text("Date")
                    Spacer()
                    Text(transaction.date.formatted())
                }
            }
            
            if let notes = transaction.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
        }
        .navigationTitle(transaction.name ?? "Transaction")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTransactionView(transaction: transaction)
        }
    }
}

struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let transaction: Transaction
    
    @State private var name: String
    @State private var amount: String
    @State private var category: String
    @State private var date: Date
    @State private var notes: String
    
    init(transaction: Transaction) {
        self.transaction = transaction
        _name = State(initialValue: transaction.name ?? "")
        _amount = State(initialValue: String(abs(transaction.amount)))
        _category = State(initialValue: transaction.category ?? TransactionCategory.uncategorized.rawValue)
        _date = State(initialValue: transaction.date)
        _notes = State(initialValue: transaction.notes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    Picker("Category", selection: $category) {
                        ForEach(TransactionCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category.rawValue)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTransaction()
                    }
                    .disabled(name.isEmpty || amount.isEmpty)
                }
            }
        }
    }
    
    private func saveTransaction() {
        guard let amountValue = Double(amount) else { return }
        
        transaction.name = name
        transaction.amount = abs(amountValue)
        transaction.category = category
        transaction.date = date
        transaction.notes = notes.isEmpty ? nil : notes
        
        dismiss()
    }
}

struct TransactionCategoryDetailView: View {
    let category: String
    @Query private var transactions: [Transaction]
    @Environment(\.modelContext) private var modelContext
    
    init(category: String) {
        self.category = category
        let predicate = #Predicate<Transaction> { transaction in
            transaction.category == category
        }
        _transactions = Query(filter: predicate)
    }
    
    var body: some View {
        List {
            ForEach(transactions) { transaction in
                NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                    TransactionListItem(transaction: transaction)
                }
            }
            .onDelete(perform: deleteTransactions)
        }
        .navigationTitle(category)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
    
    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            let transaction = transactions[index]
            modelContext.delete(transaction)
        }
    }
}

struct TransactionCategoryChartView: View {
    let categoryTotals: [(category: String, amount: Double)]
    
    private func categoryColor(for category: String) -> Color {
        TransactionCategory(rawValue: category)?.color ?? .gray
    }
    
    var body: some View {
        let totalAmount = max(categoryTotals.reduce(0) { $0 + $1.amount }, 0)
        Chart(categoryTotals, id: \.category) { item in
            BarMark(
                x: .value("Amount", item.amount)
            )
            .foregroundStyle(categoryColor(for: item.category))
            .position(by: .value("Category", item.category))
        }
        .chartXScale(domain: 0...totalAmount)
        .chartPlotStyle { plotArea in
            plotArea.background(.clear)
        }
        .listRowInsets(EdgeInsets())
        .frame(height: 200)
        .padding()
    }
}

#Preview {
    TransactionsView()
        .modelContainer(PreviewData.createPreviewContainer())
} 
