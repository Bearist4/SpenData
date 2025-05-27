import WidgetKit
import SwiftUI
import SwiftData

struct TransactionBudgetWidgetEntry: TimelineEntry {
    let date: Date
    let budgets: [TransactionBudget]
    let spentAmounts: [String: Double]
}

struct TransactionBudgetWidgetProvider: TimelineProvider {
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([TransactionBudget.self, Transaction.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [modelConfiguration])
    }()
    
    func placeholder(in context: Context) -> TransactionBudgetWidgetEntry {
        TransactionBudgetWidgetEntry(
            date: Date(),
            budgets: [],
            spentAmounts: [:]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TransactionBudgetWidgetEntry) -> ()) {
        let entry = TransactionBudgetWidgetEntry(
            date: Date(),
            budgets: [],
            spentAmounts: [:]
        )
        completion(entry)
    }

    @MainActor
    func getTimeline(in context: Context, completion: @escaping (Timeline<TransactionBudgetWidgetEntry>) -> ()) {
        let context = Self.sharedModelContainer.mainContext
        
        let budgets = try! context.fetch(FetchDescriptor<TransactionBudget>())
        let transactions = try! context.fetch(FetchDescriptor<Transaction>())
        
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        var spentAmounts: [String: Double] = [:]
        
        for budget in budgets {
            guard let category = budget.category else { continue }
            let spent = transactions
                .filter { $0.category == category && $0.date >= startOfMonth && $0.date < endOfMonth }
                .reduce(0) { $0 + abs($1.amount) }
            spentAmounts[category] = spent
        }
        
        let entry = TransactionBudgetWidgetEntry(
            date: Date(),
            budgets: budgets.filter { $0.limit ?? 0 > 0 },
            spentAmounts: spentAmounts
        )
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct TransactionBudgetWidgetEntryView: View {
    var entry: TransactionBudgetWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallBudgetWidgetView(entry: entry)
        case .systemMedium:
            MediumBudgetWidgetView(entry: entry)
        case .systemLarge:
            LargeBudgetWidgetView(entry: entry)
        default:
            Text("Unsupported widget size")
        }
    }
}

struct SmallBudgetWidgetView: View {
    let entry: TransactionBudgetWidgetEntry
    
    var body: some View {
        if let budget = entry.budgets.first {
            VStack(alignment: .leading, spacing: 8) {
                Text(budget.category ?? "Uncategorized")
                    .font(.headline)
                    .lineLimit(1)
                
                let spent = entry.spentAmounts[budget.category ?? ""] ?? 0
                let limit = budget.limit ?? 0
                let progress = limit > 0 ? min(spent / limit, 1.0) : 0
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(progress > 1.0 ? Color.red : Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text(FormattingUtils.formatCurrency(spent))
                            .font(.caption2)
                            .bold()
                        Text("of")
                            .font(.caption2)
                        Text(FormattingUtils.formatCurrency(limit))
                            .font(.caption2)
                    }
                }
                .padding(4)
            }
            .padding()
        } else {
            Text("No budgets set")
                .foregroundStyle(.secondary)
        }
    }
}

struct MediumBudgetWidgetView: View {
    let entry: TransactionBudgetWidgetEntry
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(entry.budgets.prefix(2)), id: \.id) { budget in
                VStack(alignment: .leading, spacing: 8) {
                    Text(budget.category ?? "Uncategorized")
                        .font(.headline)
                        .lineLimit(1)
                    
                    let spent = entry.spentAmounts[budget.category ?? ""] ?? 0
                    let limit = budget.limit ?? 0
                    let progress = limit > 0 ? min(spent / limit, 1.0) : 0
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(progress > 1.0 ? Color.red : Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        
                        VStack {
                            Text(FormattingUtils.formatCurrency(spent))
                                .font(.caption2)
                                .bold()
                            Text("of")
                                .font(.caption2)
                            Text(FormattingUtils.formatCurrency(limit))
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct LargeBudgetWidgetView: View {
    let entry: TransactionBudgetWidgetEntry
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(entry.budgets.prefix(4)), id: \.id) { budget in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(budget.category ?? "Uncategorized")
                            .font(.headline)
                        Spacer()
                        let spent = entry.spentAmounts[budget.category ?? ""] ?? 0
                        let limit = budget.limit ?? 0
                        Text("\(FormattingUtils.formatCurrency(spent)) / \(FormattingUtils.formatCurrency(limit))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    let spent = entry.spentAmounts[budget.category ?? ""] ?? 0
                    let limit = budget.limit ?? 0
                    let progress = limit > 0 ? min(spent / limit, 1.0) : 0
                    
                    ProgressView(value: progress)
                        .tint(progress > 1.0 ? .red : .blue)
                }
            }
        }
        .padding()
    }
}

struct TransactionBudgetWidget: Widget {
    let kind: String = "TransactionBudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TransactionBudgetWidgetProvider()) { entry in
            TransactionBudgetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Transaction Budgets")
        .description("Track your spending against budget limits.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    TransactionBudgetWidget()
} timeline: {
    TransactionBudgetWidgetEntry(
        date: .now,
        budgets: [],
        spentAmounts: [:]
    )
}

#Preview(as: .systemMedium) {
    TransactionBudgetWidget()
} timeline: {
    TransactionBudgetWidgetEntry(
        date: .now,
        budgets: [],
        spentAmounts: [:]
    )
}

#Preview(as: .systemLarge) {
    TransactionBudgetWidget()
} timeline: {
    TransactionBudgetWidgetEntry(
        date: .now,
        budgets: [],
        spentAmounts: [:]
    )
} 