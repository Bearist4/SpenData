    import SwiftUI
import SwiftData
import Charts

struct CategoryChartView: View {
    let categoryTotals: [(category: String, amount: Double)]
    
    private func categoryColor(for category: String) -> Color {
        BillCategory(rawValue: category)?.color ?? .gray
    }
    
    var body: some View {
        let totalAmount = categoryTotals.reduce(0) { $0 + $1.amount }
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
    }
}

struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var bills: [Bill]
    @State private var selectedDate: Date?
    @State private var showingAddBill = false
    
    private struct BillKey: Hashable {
        let name: String
        let issuer: String
        let category: String
    }

    private var uniqueBills: [Bill] {
        let grouped = Dictionary(grouping: bills) { (bill: Bill) in
            BillKey(
                name: bill.name ?? "",
                issuer: bill.issuer ?? "",
                category: bill.category ?? ""
            )
        }
        // For each group, pick the bill with the latest (or next upcoming) firstInstallment
        return grouped.values.compactMap { group in
            group.sorted { $0.firstInstallment > $1.firstInstallment }.first
        }
    }

    private var categorySummaries: [(category: String, amount: Double, count: Int)] {
        let groupedBills = Dictionary(grouping: uniqueBills) { $0.category ?? BillCategory.uncategorized.rawValue }
        return groupedBills.map { (category, bills) in
            let totalAmount = bills.reduce(0) { $0 + ($1.amount / Double($1.isShared ? $1.numberOfShares : 1)) }
            return (category: category, amount: totalAmount, count: bills.count)
        }.sorted { $0.amount > $1.amount }
    }
    
    private func categoryColor(for category: String) -> Color {
        BillCategory(rawValue: category)?.color ?? .gray
    }
    
    private struct DailyCategoryData: Identifiable {
        let id = UUID()
        let date: Date
        let category: String
        let amount: Double
    }
    
    private func calculateDailyAmounts() -> [DailyCategoryData] {
        let calendar = Calendar.current
        
        // First, create the basic data points
        let dataPoints = bills.map { bill -> DailyCategoryData in
            let date = calendar.startOfDay(for: bill.firstInstallment)
            let category = bill.category ?? BillCategory.uncategorized.rawValue
            let amount = bill.amount / Double(bill.isShared ? bill.numberOfShares : 1)
            return DailyCategoryData(date: date, category: category, amount: amount)
        }
        
        // Then sort by date
        return dataPoints.sorted { $0.date < $1.date }
    }
    
    private var dailyCategoryAmounts: [DailyCategoryData] {
        calculateDailyAmounts()
    }
    
    private var selectedData: DailyCategoryData? {
        guard let selectedDate else { return nil }
        let calendar = Calendar.current
        return dailyCategoryAmounts.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    private var categoryTotals: [(category: String, amount: Double)] {
        let grouped = Dictionary(grouping: uniqueBills) { $0.category ?? BillCategory.uncategorized.rawValue }
        return grouped.map { (category, bills) in
            let total = bills.reduce(0) { $0 + ($1.amount / Double($1.isShared ? $1.numberOfShares : 1)) }
            return (category: category, amount: total)
        }.sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !dailyCategoryAmounts.isEmpty {
                    Section() {
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Total Spending by Category")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                CategoryChartView(categoryTotals: categoryTotals)
                            }
                        }
                    }
                }
                
                Section("Categories") {
                    ForEach(categorySummaries, id: \.category) { summary in
                        NavigationLink(destination: CategoryDetailView(category: summary.category)) {
                            HStack {
                                Circle()
                                    .fill(categoryColor(for: summary.category))
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
}

struct CategoryDetailView: View {
    let category: String
    @Query private var bills: [Bill]
    @Environment(\.modelContext) private var modelContext
    
    init(category: String) {
        self.category = category
        let predicate = #Predicate<Bill> { bill in
            bill.category == category
        }
        _bills = Query(filter: predicate)
    }
    
    var body: some View {
        List {
            ForEach(bills) { bill in
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
                        Text("Next due: \(bill.firstInstallment, style: .date)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if bill.isShared {
                        Text("Shared: \(bill.numberOfShares) people")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
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
            let bill = bills[index]
            modelContext.delete(bill)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error deleting bills: \(error)")
        }
    }
}

#Preview {
    BillsView()
        .modelContainer(PreviewData.createPreviewContainer())
} 
