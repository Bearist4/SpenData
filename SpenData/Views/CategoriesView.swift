import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var bills: [Bill]
    @State private var selectedMonth = Date()
    
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        return calendar
    }
    
    private var startOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
    }
    
    private var endOfMonth: Date {
        calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
    }
    
    private var transactionCategories: [(category: String, amount: Double)] {
        let filteredTransactions = transactions.filter { $0.date >= startOfMonth && $0.date < endOfMonth }
        let grouped = Dictionary(grouping: filteredTransactions) { $0.category ?? TransactionCategory.uncategorized.rawValue }
        return grouped.map { (category, transactions) in
            let total = transactions.reduce(0) { $0 + abs($1.amount) }
            return (category: category, amount: total)
        }.sorted { $0.amount > $1.amount }
    }
    
    private var billCategories: [(category: String, amount: Double)] {
        let filteredBills = bills.filter { $0.firstInstallment >= startOfMonth && $0.firstInstallment < endOfMonth }
        let grouped = Dictionary(grouping: filteredBills) { $0.category ?? BillCategory.uncategorized.rawValue }
        return grouped.map { (category, bills) in
            let total = bills.reduce(0) { $0 + ($1.amount / Double($1.isShared ? $1.numberOfShares : 1)) }
            return (category: category, amount: total)
        }.sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        List {
            Section {
                DatePicker("Select Month", selection: $selectedMonth, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .padding(.vertical, 8)
            }
            
            Section("Transaction Categories") {
                ForEach(transactionCategories, id: \.category) { category in
                    NavigationLink(destination: CategoryHistoryView(
                        category: category.category,
                        isBill: false,
                        selectedMonth: selectedMonth
                    )) {
                        HStack {
                            Circle()
                                .fill(TransactionCategory(rawValue: category.category)?.color ?? .gray)
                                .frame(width: 12, height: 12)
                            Text(category.category)
                            Spacer()
                            Text(FormattingUtils.formatCurrency(category.amount))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Section("Bill Categories") {
                ForEach(billCategories, id: \.category) { category in
                    NavigationLink(destination: CategoryHistoryView(
                        category: category.category,
                        isBill: true,
                        selectedMonth: selectedMonth
                    )) {
                        HStack {
                            Circle()
                                .fill(BillCategory(rawValue: category.category)?.color ?? .gray)
                                .frame(width: 12, height: 12)
                            Text(category.category)
                            Spacer()
                            Text(FormattingUtils.formatCurrency(category.amount))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Categories")
    }
}

struct CategoryHistoryView: View {
    let category: String
    let isBill: Bool
    let selectedMonth: Date
    
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var bills: [Bill]
    @State private var showingMonthPicker = false
    
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        return calendar
    }
    
    private var startOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
    }
    
    private var endOfMonth: Date {
        calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
    }
    
    private var monthlyAmounts: [(date: Date, amount: Double)] {
        var amounts: [(date: Date, amount: Double)] = []
        let monthsToShow = 12
        
        for i in 0..<monthsToShow {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: startOfMonth),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                continue
            }
            
            var total: Double = 0
            
            if isBill {
                let monthBills = bills.filter { $0.category == category && $0.firstInstallment >= monthStart && $0.firstInstallment < monthEnd }
                total = monthBills.reduce(0) { $0 + ($1.amount / Double($1.isShared ? $1.numberOfShares : 1)) }
            } else {
                let monthTransactions = transactions.filter { $0.category == category && $0.date >= monthStart && $0.date < monthEnd }
                total = monthTransactions.reduce(0) { $0 + abs($1.amount) }
            }
            
            amounts.append((date: monthStart, amount: total))
        }
        
        return amounts.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        List {
            Section {
                ForEach(monthlyAmounts, id: \.date) { monthData in
                    HStack {
                        Text(monthData.date.formatted(.dateTime.month().year()))
                        Spacer()
                        Text(FormattingUtils.formatCurrency(monthData.amount))
                            .foregroundStyle(monthData.amount > 0 ? .primary : .secondary)
                    }
                }
            } header: {
                Text("Monthly History")
            }
            
            if isBill {
                Section {
                    ForEach(bills.filter { $0.category == category && $0.firstInstallment >= startOfMonth && $0.firstInstallment < endOfMonth }) { bill in
                        NavigationLink(destination: BillDetailView(bill: bill)) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(bill.name ?? "Unnamed Bill")
                                        .font(.headline)
                                    Spacer()
                                    Text(FormattingUtils.formatCurrency(bill.amount / Double(bill.isShared ? bill.numberOfShares : 1)))
                                        .font(.headline)
                                }
                                
                                HStack {
                                    Text(bill.issuer ?? "Unknown Issuer")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("Due: \(bill.firstInstallment, style: .date)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Current Month Bills")
                }
            } else {
                Section {
                    ForEach(transactions.filter { $0.category == category && $0.date >= startOfMonth && $0.date < endOfMonth }) { transaction in
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TransactionListItem(transaction: transaction)
                        }
                    }
                } header: {
                    Text("Current Month Transactions")
                }
            }
        }
        .navigationTitle(category)
    }
}

#Preview {
    NavigationStack {
        CategoriesView()
    }
    .modelContainer(PreviewData.createPreviewContainer())
} 