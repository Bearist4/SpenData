//
//  TransactionBudgetWidget.swift
//  TransactionBudgetWidget
//
//  Created by Benjamin CAILLET on 25.05.25.
//

import WidgetKit
import SwiftUI
import SwiftData
import SpenDataModels
import AppIntents
import Intents
import os.log

@MainActor
struct SharedContainer {
    static func createContainer() -> ModelContainer {
        let logger = Logger(subsystem: "com.spendata.widget", category: "Database")
        
        logger.debug("Initializing SharedContainer")
        
        let schema: Schema = Schema([
            SpenDataModels.User.self,
            SpenDataModels.Transaction.self,
            SpenDataModels.TransactionBudget.self
        ])
        
        logger.debug("Schema created with models: User, Transaction, TransactionBudget")
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic
        )
        
        logger.debug("ModelConfiguration created with CloudKit sync enabled")
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            logger.debug("Successfully created ModelContainer")
            
            // Verify we can access the context
            let context = container.mainContext
            logger.debug("Successfully accessed mainContext")
            
            // Try to fetch any data to verify access
            do {
                let userCount = try context.fetch(FetchDescriptor<SpenDataModels.User>()).count
                let transactionCount = try context.fetch(FetchDescriptor<SpenDataModels.Transaction>()).count
                let budgetCount = try context.fetch(FetchDescriptor<SpenDataModels.TransactionBudget>()).count
                
                logger.debug("Initial data check - Users: \(userCount), Transactions: \(transactionCount), Budgets: \(budgetCount)")
            } catch {
                logger.error("Failed to perform initial data check: \(error.localizedDescription)")
            }
            
            return container
        } catch {
            logger.error("Failed to create ModelContainer: \(error.localizedDescription)")
            logger.error("Error details: \(error)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    static let shared = createContainer()
}

actor DatabaseActor {
    private let container: ModelContainer
    private let logger = Logger(subsystem: "com.spendata.widget", category: "Database")
    
    init(container: ModelContainer) {
        self.container = container
        logger.debug("DatabaseActor initialized")
    }
    
    @MainActor
    private func performFetch<T>(_ descriptor: FetchDescriptor<T>) async throws -> [T] {
        logger.debug("Starting fetch operation for type: \(String(describing: T.self))")
        do {
            let results = try await container.mainContext.fetch(descriptor)
            logger.debug("Fetch completed successfully with \(results.count) results")
            
            // Log details about the results
            if let firstResult = results.first {
                logger.debug("First result type: \(type(of: firstResult))")
                if let budget = firstResult as? SpenDataModels.TransactionBudget {
                    logger.debug("First budget - Category: \(budget.category ?? "nil"), Limit: \(budget.limit ?? 0), Period: \(budget.period ?? "nil"), Active: \(budget.isActive)")
                }
            }
            
            return results
        } catch {
            logger.error("Fetch failed: \(error.localizedDescription)")
            logger.error("Error details: \(error)")
            throw error
        }
    }
    
    func fetch<T>(_ descriptor: FetchDescriptor<T>) async throws -> [T] {
        logger.debug("Fetch requested for type: \(String(describing: T.self))")
        return try await performFetch(descriptor)
    }
}

struct BudgetOptionsProvider: DynamicOptionsProvider {
    typealias Result = [String]
    
    private let logger: Logger = Logger(subsystem: "com.spendata.widget", category: "BudgetOptions")
    private let databaseActor: DatabaseActor
    
    init() {
        logger.debug("Initializing BudgetOptionsProvider")
        self.databaseActor = DatabaseActor(container: SharedContainer.shared)
    }
    
    func results() async throws -> [String] {
        do {
            logger.debug("Starting budget fetch...")
            let budgets: [SpenDataModels.TransactionBudget] = try await databaseActor.fetch(FetchDescriptor<SpenDataModels.TransactionBudget>())
            logger.debug("Total budgets fetched: \(budgets.count)")
            
            if budgets.isEmpty {
                logger.debug("No budgets found in the database")
                return ["No active monthly budgets"]
            }
            
            // Log details about each budget
            for (index, budget) in budgets.enumerated() {
                logger.debug("Budget \(index + 1):")
                logger.debug("  - Category: \(budget.category ?? "nil")")
                logger.debug("  - Limit: \(budget.limit ?? 0)")
                logger.debug("  - Period: \(budget.period ?? "nil")")
                logger.debug("  - Active: \(budget.isActive)")
            }
            
            // Filter in memory and ensure we have at least one result
            let filteredBudgets: [String] = budgets
                .filter { budget in
                    guard let limit = budget.limit,
                          limit > 0,
                          budget.isActive,
                          budget.period == "Monthly" else {
                        return false
                    }
                    return true
                }
                .compactMap { $0.category }
                .sorted()
            
            logger.debug("Filtered budgets count: \(filteredBudgets.count)")
            logger.debug("Filtered budget categories: \(filteredBudgets.joined(separator: ", "))")
            
            // If no budgets are found, return a default option
            if filteredBudgets.isEmpty {
                logger.debug("No active monthly budgets found after filtering")
                return ["No active monthly budgets"]
            }
            
            return filteredBudgets
        } catch {
            logger.error("Error fetching budgets: \(error.localizedDescription)")
            logger.error("Error details: \(error)")
            return ["Error loading budgets"]
        }
    }
}

// Single Budget Widget
struct SingleBudgetSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Budget"
    static var description: LocalizedStringResource = "Choose a budget to display"
    
    @Parameter(title: "Budget", optionsProvider: BudgetOptionsProvider())
    var budget: String?
    
    init() {}
    
    init(budget: String? = nil) {
        self.budget = budget
    }
    
    func parameterSummary() -> some ParameterSummary {
        if budget == nil {
            return Summary("No budget selected")
        } else {
            return Summary("\(\.$budget)")
        }
    }
}

// Single Budget Widget Provider
struct SingleBudgetWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = TransactionBudgetWidgetEntry
    typealias Intent = SingleBudgetSelectionIntent
    
    private let databaseActor: DatabaseActor
    
    init() {
        self.databaseActor = DatabaseActor(container: SharedContainer.shared)
    }
    
    func placeholder(in context: Context) -> TransactionBudgetWidgetEntry {
        TransactionBudgetWidgetEntry(
            date: Date(),
            budgets: [PreviewData.sampleBudgets[0]],
            spentAmounts: ["Groceries": PreviewData.sampleSpentAmounts["Groceries"]!],
            configuration: SingleBudgetSelectionIntent(budget: "Groceries")
        )
    }

    func snapshot(for configuration: SingleBudgetSelectionIntent, in context: Context) async -> TransactionBudgetWidgetEntry {
        await createEntry(for: [configuration.budget])
    }

    func timeline(for configuration: SingleBudgetSelectionIntent, in context: Context) async -> Timeline<TransactionBudgetWidgetEntry> {
        let entry = await createEntry(for: [configuration.budget])
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(5)))
    }
    
    private func createEntry(for selectedBudgets: [String?]) async -> TransactionBudgetWidgetEntry {
        do {
            let allBudgets = try await databaseActor.fetch(FetchDescriptor<SpenDataModels.TransactionBudget>())
            let transactions = try await databaseActor.fetch(FetchDescriptor<SpenDataModels.Transaction>())
            
            let calendar = Calendar.current
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            
            var spentAmounts: [String: Double] = [:]
            
            let selectedBudgets = allBudgets.filter { budget in
                guard let category = budget.category,
                      budget.isActive,
                      budget.period == "Monthly",
                      let limit = budget.limit,
                      limit > 0 else { return false }
                
                return selectedBudgets.contains(category)
            }
            
            for budget in selectedBudgets {
                guard let category = budget.category else { continue }
                
                let categoryTransactions = transactions.filter { transaction in
                    transaction.category == category &&
                    transaction.date >= startOfMonth &&
                    transaction.date < endOfMonth
                }
                
                let spent = categoryTransactions.reduce(0.0) { $0 + abs($1.amount) }
                spentAmounts[category] = spent
            }
            
            return TransactionBudgetWidgetEntry(
                date: Date(),
                budgets: selectedBudgets,
                spentAmounts: spentAmounts,
                configuration: SingleBudgetSelectionIntent()
            )
        } catch {
            print("Error creating entry: \(error)")
            return TransactionBudgetWidgetEntry(
                date: Date(),
                budgets: [],
                spentAmounts: [:],
                configuration: SingleBudgetSelectionIntent()
            )
        }
    }
}

struct SingleBudgetWidget: Widget {
    let kind: String = "SingleBudgetWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SingleBudgetSelectionIntent.self, provider: SingleBudgetWidgetProvider()) { entry in
            SmallBudgetWidgetView(entry: entry)
                .containerBackground(Color.clear, for: .widget)
        }
        .configurationDisplayName("Single Budget")
        .description("Track a single budget's spending.")
        .supportedFamilies([.systemSmall])
    }
}

// Two Budgets Widget
struct TwoBudgetsSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Budgets"
    static var description: LocalizedStringResource = "Choose two budgets to display"
    
    @Parameter(title: "First Budget", optionsProvider: BudgetOptionsProvider())
    var budget1: String?
    
    @Parameter(title: "Second Budget", optionsProvider: BudgetOptionsProvider())
    var budget2: String?
    
    init() {}
    
    init(budget1: String? = nil, budget2: String? = nil) {
        self.budget1 = budget1
        self.budget2 = budget2
    }
    
    func parameterSummary() -> some ParameterSummary {
        if budget1 == nil {
            return Summary("No budgets selected")
        } else if budget2 == nil {
            return Summary { \.$budget1 }
        } else {
            return Summary("\(\.$budget1), \(\.$budget2)")
        }
    }
}

// Two Budgets Widget Provider
struct TwoBudgetsWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = TransactionBudgetWidgetEntry
    typealias Intent = TwoBudgetsSelectionIntent
    
    private let databaseActor: DatabaseActor
    
    init() {
        self.databaseActor = DatabaseActor(container: SharedContainer.shared)
    }
    
    func placeholder(in context: Context) -> TransactionBudgetWidgetEntry {
        TransactionBudgetWidgetEntry(
            date: Date(),
            budgets: Array(PreviewData.sampleBudgets.prefix(2)),
            spentAmounts: [
                "Groceries": PreviewData.sampleSpentAmounts["Groceries"]!,
                "Dining Out": PreviewData.sampleSpentAmounts["Dining Out"]!
            ],
            configuration: TwoBudgetsSelectionIntent(
                budget1: "Groceries",
                budget2: "Dining Out"
            )
        )
    }

    func snapshot(for configuration: TwoBudgetsSelectionIntent, in context: Context) async -> TransactionBudgetWidgetEntry {
        await createEntry(for: [configuration.budget1, configuration.budget2])
    }

    func timeline(for configuration: TwoBudgetsSelectionIntent, in context: Context) async -> Timeline<TransactionBudgetWidgetEntry> {
        let entry = await createEntry(for: [configuration.budget1, configuration.budget2])
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(5)))
    }
    
    private func createEntry(for selectedBudgets: [String?]) async -> TransactionBudgetWidgetEntry {
        do {
            let allBudgets = try await databaseActor.fetch(FetchDescriptor<SpenDataModels.TransactionBudget>())
            let transactions = try await databaseActor.fetch(FetchDescriptor<SpenDataModels.Transaction>())
            
            let calendar = Calendar.current
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            
            var spentAmounts: [String: Double] = [:]
            
            let selectedBudgets = allBudgets.filter { budget in
                guard let category = budget.category,
                      budget.isActive,
                      budget.period == "Monthly",
                      let limit = budget.limit,
                      limit > 0 else { return false }
                
                return selectedBudgets.contains(category)
            }
            
            for budget in selectedBudgets {
                guard let category = budget.category else { continue }
                
                let categoryTransactions = transactions.filter { transaction in
                    transaction.category == category &&
                    transaction.date >= startOfMonth &&
                    transaction.date < endOfMonth
                }
                
                let spent = categoryTransactions.reduce(0.0) { $0 + abs($1.amount) }
                spentAmounts[category] = spent
            }
            
            return TransactionBudgetWidgetEntry(
                date: Date(),
                budgets: selectedBudgets,
                spentAmounts: spentAmounts,
                configuration: TwoBudgetsSelectionIntent()
            )
        } catch {
            print("Error creating entry: \(error)")
            return TransactionBudgetWidgetEntry(
                date: Date(),
                budgets: [],
                spentAmounts: [:],
                configuration: TwoBudgetsSelectionIntent()
            )
        }
    }
}

struct TwoBudgetsWidget: Widget {
    let kind: String = "TwoBudgetsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TwoBudgetsSelectionIntent.self, provider: TwoBudgetsWidgetProvider()) { entry in
            MediumBudgetWidgetView(entry: entry)
                .containerBackground(Color.clear, for: .widget)
        }
        .configurationDisplayName("Two Budgets")
        .description("Track two budgets' spending.")
        .supportedFamilies([.systemMedium])
    }
}

// Four Budgets Widget
struct FourBudgetsSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Budgets"
    static var description: LocalizedStringResource = "Choose up to four budgets to display"
    
    @Parameter(title: "First Budget", optionsProvider: BudgetOptionsProvider())
    var budget1: String?
    
    @Parameter(title: "Second Budget", optionsProvider: BudgetOptionsProvider())
    var budget2: String?
    
    @Parameter(title: "Third Budget", optionsProvider: BudgetOptionsProvider())
    var budget3: String?
    
    @Parameter(title: "Fourth Budget", optionsProvider: BudgetOptionsProvider())
    var budget4: String?
    
    init() {}
    
    init(budget1: String? = nil, budget2: String? = nil, budget3: String? = nil, budget4: String? = nil) {
        self.budget1 = budget1
        self.budget2 = budget2
        self.budget3 = budget3
        self.budget4 = budget4
    }
    
    func parameterSummary() -> some ParameterSummary {
        if budget1 == nil {
            return Summary("No budgets selected")
        } else if budget2 == nil {
            return Summary("\(\.$budget1)")
        } else if budget3 == nil {
            return Summary("\(\.$budget1), \(\.$budget2)")
        } else if budget4 == nil {
            return Summary("\(\.$budget1), \(\.$budget2), \(\.$budget3)")
        } else {
            return Summary("\(\.$budget1), \(\.$budget2), \(\.$budget3), \(\.$budget4)")
        }
    }
}

// Four Budgets Widget Provider
struct FourBudgetsWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = TransactionBudgetWidgetEntry
    typealias Intent = FourBudgetsSelectionIntent
    
    private let databaseActor: DatabaseActor
    
    init() {
        self.databaseActor = DatabaseActor(container: SharedContainer.shared)
    }
    
    func placeholder(in context: Context) -> TransactionBudgetWidgetEntry {
        TransactionBudgetWidgetEntry(
            date: Date(),
            budgets: PreviewData.sampleBudgets,
            spentAmounts: PreviewData.sampleSpentAmounts,
            configuration: FourBudgetsSelectionIntent(
                budget1: "Groceries",
                budget2: "Dining Out",
                budget3: "Transportation",
                budget4: "Entertainment"
            )
        )
    }

    func snapshot(for configuration: FourBudgetsSelectionIntent, in context: Context) async -> TransactionBudgetWidgetEntry {
        await createEntry(for: [configuration.budget1, configuration.budget2, configuration.budget3, configuration.budget4])
    }

    func timeline(for configuration: FourBudgetsSelectionIntent, in context: Context) async -> Timeline<TransactionBudgetWidgetEntry> {
        let entry = await createEntry(for: [configuration.budget1, configuration.budget2, configuration.budget3, configuration.budget4])
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(5)))
    }
    
    private func createEntry(for selectedBudgets: [String?]) async -> TransactionBudgetWidgetEntry {
        do {
            let allBudgets = try await databaseActor.fetch(FetchDescriptor<SpenDataModels.TransactionBudget>())
            let transactions = try await databaseActor.fetch(FetchDescriptor<SpenDataModels.Transaction>())
            
            let calendar = Calendar.current
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            
            var spentAmounts: [String: Double] = [:]
            
            let selectedBudgets = allBudgets.filter { budget in
                guard let category = budget.category,
                      budget.isActive,
                      budget.period == "Monthly",
                      let limit = budget.limit,
                      limit > 0 else { return false }
                
                return selectedBudgets.contains(category)
            }
            
            for budget in selectedBudgets {
                guard let category = budget.category else { continue }
                
                let categoryTransactions = transactions.filter { transaction in
                    transaction.category == category &&
                    transaction.date >= startOfMonth &&
                    transaction.date < endOfMonth
                }
                
                let spent = categoryTransactions.reduce(0.0) { $0 + abs($1.amount) }
                spentAmounts[category] = spent
            }
            
            return TransactionBudgetWidgetEntry(
                date: Date(),
                budgets: selectedBudgets,
                spentAmounts: spentAmounts,
                configuration: FourBudgetsSelectionIntent()
            )
        } catch {
            print("Error creating entry: \(error)")
            return TransactionBudgetWidgetEntry(
                date: Date(),
                budgets: [],
                spentAmounts: [:],
                configuration: FourBudgetsSelectionIntent()
            )
        }
    }
}

struct FourBudgetsWidget: Widget {
    let kind: String = "FourBudgetsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: FourBudgetsSelectionIntent.self, provider: FourBudgetsWidgetProvider()) { entry in
            LargeBudgetWidgetView(entry: entry)
                .containerBackground(Color.clear, for: .widget)
        }
        .configurationDisplayName("Four Budgets")
        .description("Track up to four budgets' spending.")
        .supportedFamilies([.systemLarge])
    }
}

struct TransactionBudgetWidgetEntry: TimelineEntry {
    let date: Date
    let budgets: [SpenDataModels.TransactionBudget]
    let spentAmounts: [String: Double]
    let configuration: any WidgetConfigurationIntent
}

struct TransactionBudgetWidgetEntryView: View {
    var entry: TransactionBudgetWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallBudgetWidgetView(entry: entry)
        case .systemMedium:
            MediumBudgetWidgetView(entry: entry)
        case .systemLarge:
            LargeBudgetWidgetView(entry: entry)
        @unknown default:
            Text("Unsupported widget size")
        }
    }
}

struct SmallBudgetWidgetView: View {
    let entry: TransactionBudgetWidgetEntry
    
    private func progressColor(for percent: Double) -> Color {
        switch percent {
        case ..<0.25: return .blue
        case 0.25..<0.5: return .green
        case 0.5..<0.7: return .yellow
        case 0.7..<0.85: return .orange
        default: return .red
        }
    }
    
    // Returns (symbol, value, symbolIsPrefix)
    private func splitCurrency(amount: Double, currencyCode: String = Locale.current.currency?.identifier ?? "EUR") -> (String, String, Bool) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale.current
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
        let symbol = formatter.currencySymbol ?? "€"
        if let range = formatted.range(of: symbol) {
            let value = formatted.replacingOccurrences(of: symbol, with: "").trimmingCharacters(in: .whitespaces)
            let symbolIsPrefix = range.lowerBound == formatted.startIndex
            return (symbol, value, symbolIsPrefix)
        } else {
            // fallback
            return (symbol, formatted, true)
        }
    }
    
    var body: some View {
        if let budget = entry.budgets.first {
            let spent = entry.spentAmounts[budget.category ?? ""] ?? 0.0
            let limit = budget.limit ?? 0.0
            let progress = limit > 0.0 ? min(spent / limit, 1.0) : 0.0
            let color = progressColor(for: progress)
            let currency = Locale.current.currency?.identifier ?? "EUR"
            let (symbol, value, symbolIsPrefix) = splitCurrency(amount: spent, currencyCode: currency)
            let (limitSymbol, limitValue, limitSymbolIsPrefix) = splitCurrency(amount: limit, currencyCode: currency)
            
            VStack(alignment: .center, spacing: 0) {
                // Top: Budget name (left-aligned)
                HStack {
                    Text(budget.category ?? "Uncategorized")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 8)
                
                Spacer(minLength: 0)
                
                // Middle: Progress ring (centered)
                HStack {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 40, height: 40)
                    Spacer()
                }
                .padding(.vertical, 0)
                
                Spacer(minLength: 0)
                
                // Bottom: Value block (centered)
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        if symbolIsPrefix {
                            Text(symbol)
                                .font(.callout)
                                .foregroundColor(.secondary)
                            Text(value)
                                .font(.title3)
                                .bold()
                                .fontDesign(.rounded)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        } else {
                            Text(value)
                                .font(.title3)
                                .bold()
                                .fontDesign(.rounded)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(symbol)
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 2) {
                        if limitSymbolIsPrefix {
                            Text("out of ")
                            Text(limitSymbol)
                            Text(limitValue)
                        } else {
                            Text("out of ")
                            Text(limitValue)
                            Text(limitSymbol)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.gray)
                    .font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            }
            
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            Text("No budgets set")
                .foregroundStyle(.secondary)
                .padding(16)
        }
    }
}

struct MediumBudgetWidgetView: View {
    let entry: TransactionBudgetWidgetEntry

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 24) {
                // First half
                VStack {
                    SmallBudgetWidgetView(entry: TransactionBudgetWidgetEntry(
                        date: entry.date,
                        budgets: entry.budgets.prefix(1).map { $0 },
                        spentAmounts: entry.spentAmounts,
                        configuration: entry.configuration
                    ))
                }
//                .frame(width: geometry.size.width / 2.5, height: geometry.size.height)
                
                // Divider with 16px spacing on each side

                VStack {
                    Spacer(minLength: 16)
                    DottedDivider()
                        .frame(width: 1, height: geometry.size.height * 0.7)
                    Spacer(minLength: 16)
                }
//                .frame(width: geometry.size.width / 100, height: geometry.size.height)

                
                // Second half
                VStack {
                    SmallBudgetWidgetView(entry: TransactionBudgetWidgetEntry(
                        date: entry.date,
                        budgets: Array(entry.budgets.dropFirst().prefix(1)),
                        spentAmounts: entry.spentAmounts,
                        configuration: entry.configuration
                    ))
                }
//                .frame(width: geometry.size.width / 2.5, height: geometry.size.height)
            }
        }
        .padding(0)
    }
}

// Custom vertical dotted divider
struct DottedDivider: View {
    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<12, id: \.self) { _ in
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 5, height: 5)
            }
        }
    }
}

struct LargeBudgetWidgetView: View {
    let entry: TransactionBudgetWidgetEntry
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(entry.budgets.prefix(4)), id: \.id) { budget in
                LargeBudgetItemView(
                    budget: budget,
                    spentAmount: entry.spentAmounts[budget.category ?? ""] ?? 0.0
                )
            }
        }
        .padding()
    }
}

private struct LargeBudgetItemView: View {
    let budget: SpenDataModels.TransactionBudget
    let spentAmount: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(budget.category ?? "Uncategorized")
                    .font(.headline)
                Spacer()
                let limit = budget.limit ?? 0.0
                Text("$\(spentAmount, specifier: "%.2f") / $\(limit, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            let limit = budget.limit ?? 0.0
            let progress = limit > 0.0 ? min(spentAmount / limit, 1.0) : 0.0
            
            ProgressView(value: progress)
                .tint(progress > 1.0 ? .red : .blue)
        }
    }
}

// Add preview data
struct PreviewData {
    static let sampleBudgets: [SpenDataModels.TransactionBudget] = [
        SpenDataModels.TransactionBudget(
            category: "Groceries",
            limit: 500.0,
            period: "Monthly",
            startDate: Date()
        ),
        SpenDataModels.TransactionBudget(
            category: "Dining Out",
            limit: 300.0,
            period: "Monthly",
            startDate: Date()
        ),
        SpenDataModels.TransactionBudget(
            category: "Transportation",
            limit: 200.0,
            period: "Monthly",
            startDate: Date()
        ),
        SpenDataModels.TransactionBudget(
            category: "Entertainment",
            limit: 150.0,
            period: "Monthly",
            startDate: Date()
        )
    ]
    
    static let sampleSpentAmounts: [String: Double] = [
        "Groceries": 30.0,
        "Dining Out": 250.0,
        "Transportation": 180.0,
        "Entertainment": 120.0
    ]
}

// Update previews
#Preview(as: .systemSmall) {
    SingleBudgetWidget()
} timeline: {
    TransactionBudgetWidgetEntry(
        date: Date(),
        budgets: [PreviewData.sampleBudgets[0]],
        spentAmounts: ["Groceries": PreviewData.sampleSpentAmounts["Groceries"]!],
        configuration: SingleBudgetSelectionIntent(budget: "Groceries")
    )
}

#Preview(as: .systemMedium) {
    TwoBudgetsWidget()
} timeline: {
    TransactionBudgetWidgetEntry(
        date: Date(),
        budgets: Array(PreviewData.sampleBudgets.prefix(2)),
        spentAmounts: [
            "Groceries": PreviewData.sampleSpentAmounts["Groceries"]!,
            "Dining Out": PreviewData.sampleSpentAmounts["Dining Out"]!
        ],
        configuration: TwoBudgetsSelectionIntent(
            budget1: "Groceries",
            budget2: "Dining Out"
        )
    )
}

#Preview(as: .systemLarge) {
    FourBudgetsWidget()
} timeline: {
    TransactionBudgetWidgetEntry(
        date: Date(),
        budgets: PreviewData.sampleBudgets,
        spentAmounts: PreviewData.sampleSpentAmounts,
        configuration: FourBudgetsSelectionIntent(
            budget1: "Groceries",
            budget2: "Dining Out",
            budget3: "Transportation",
            budget4: "Entertainment"
        )
    )
}

// MARK: - Bar with Indicator for Medium Bar Widget
struct BudgetBarWithIndicator: View {
    let percent: Double // 0.0 ... 1.0
    let color: Color
    
    private func calculateProgressWidth(_ percent: Double, in totalWidth: CGFloat) -> CGFloat {
        let minPercent: Double = 0.1 // 10%
        let displayPercent = max(percent, minPercent)
        return totalWidth * displayPercent
    }

    var body: some View {
        VStack(spacing: 4) {
            // Indicator and Bar Container
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Bar
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    // Progress
                    Capsule()
                        .fill(color)
                        .frame(width: calculateProgressWidth(percent, in: geo.size.width), height: 12)
                    
                    // Indicator
                    let pillWidth: CGFloat = 40 // Estimated width of the pill
                    let rawOffset = geo.size.width * percent - pillWidth / 2
                    let clampedOffset = min(max(rawOffset, 0), geo.size.width - pillWidth)
                    Text("\(Int(percent * 100))%")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(color)
                        )
                        .offset(x: clampedOffset)
                        .offset(y: -20) // Move up above the bar
                }
            }
            .frame(height: 16)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Medium Budget Bar Widget View
struct MediumBudgetBarWidgetView: View {
    let entry: TransactionBudgetWidgetEntry
    
    // Returns (symbol, value, symbolIsPrefix)
    private func splitCurrency(amount: Double, currencyCode: String = Locale.current.currency?.identifier ?? "EUR") -> (String, String, Bool) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale.current
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
        let symbol = formatter.currencySymbol ?? "€"
        if let range = formatted.range(of: symbol) {
            let value = formatted.replacingOccurrences(of: symbol, with: "").trimmingCharacters(in: .whitespaces)
            let symbolIsPrefix = range.lowerBound == formatted.startIndex
            return (symbol, value, symbolIsPrefix)
        } else {
            // fallback
            return (symbol, formatted, true)
        }
    }

    var body: some View {
        HStack(spacing: 24) {
            ForEach(Array(entry.budgets.prefix(2)), id: \.id) { budget in
                let spent = entry.spentAmounts[budget.category ?? ""] ?? 0.0
                let limit = budget.limit ?? 0.0
                let percent = limit > 0 ? min(spent / limit, 1.0) : 0.0
                let color: Color = {
                    switch percent {
                    case ..<0.5: return .green
                    case 0.5..<0.85: return .orange
                    default: return .red
                    }
                }()
                
                let (spentSymbol, spentValue, spentSymbolIsPrefix) = splitCurrency(amount: spent)
                let (limitSymbol, limitValue, limitSymbolIsPrefix) = splitCurrency(amount: limit)

                VStack(alignment: .leading, spacing: 8) {
                    Text(budget.category ?? "Uncategorized")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    Spacer()
                    BudgetBarWithIndicator(percent: percent, color: color)
                        .frame(height: 16)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        if spentSymbolIsPrefix {
                            Text(spentSymbol)
                                .font(.callout)
                                .foregroundColor(.secondary)
                            Text(spentValue)
                                .font(.title3)
                                .bold()
                                .fontDesign(.rounded)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        } else {
                            Text(spentValue)
                                .font(.title3)
                                .bold()
                                .fontDesign(.rounded)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(spentSymbol)
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack(spacing: 2) {
                        if limitSymbolIsPrefix {
                            Text("out of ")
                            Text(limitSymbol)
                            Text(limitValue)
                        } else {
                            Text("out of ")
                            Text(limitValue)
                            Text(limitSymbol)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.gray)
                    .font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }
}

// MARK: - Medium Budget Bar Widget Intent & Provider
struct TwoBudgetsBarSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Budgets (Bar)"
    static var description: LocalizedStringResource = "Choose two budgets to display as bars"
    
    @Parameter(title: "First Budget", optionsProvider: BudgetOptionsProvider())
    var budget1: String?
    
    @Parameter(title: "Second Budget", optionsProvider: BudgetOptionsProvider())
    var budget2: String?
    
    init() {}
    
    init(budget1: String? = nil, budget2: String? = nil) {
        self.budget1 = budget1
        self.budget2 = budget2
    }
    
    func parameterSummary() -> some ParameterSummary {
        if budget1 == nil {
            return Summary("No budgets selected")
        } else if budget2 == nil {
            return Summary { \.$budget1 }
        } else {
            return Summary("\(\.$budget1), \(\.$budget2)")
        }
    }
}

struct TwoBudgetsBarWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = TransactionBudgetWidgetEntry
    typealias Intent = TwoBudgetsBarSelectionIntent
    
    private let databaseActor: DatabaseActor
    
    init() {
        self.databaseActor = DatabaseActor(container: SharedContainer.shared)
    }
    
    func placeholder(in context: Context) -> TransactionBudgetWidgetEntry {
        TransactionBudgetWidgetEntry(
            date: Date(),
            budgets: Array(PreviewData.sampleBudgets.prefix(2)),
            spentAmounts: [
                "Groceries": PreviewData.sampleSpentAmounts["Groceries"]!,
                "Dining Out": PreviewData.sampleSpentAmounts["Dining Out"]!
            ],
            configuration: TwoBudgetsBarSelectionIntent(
                budget1: "Groceries",
                budget2: "Dining Out"
            )
        )
    }

    func snapshot(for configuration: TwoBudgetsBarSelectionIntent, in context: Context) async -> TransactionBudgetWidgetEntry {
        await createEntry(for: [configuration.budget1, configuration.budget2])
    }

    func timeline(for configuration: TwoBudgetsBarSelectionIntent, in context: Context) async -> Timeline<TransactionBudgetWidgetEntry> {
        let entry = await createEntry(for: [configuration.budget1, configuration.budget2])
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(5)))
    }
    
    private func createEntry(for selectedBudgets: [String?]) async -> TransactionBudgetWidgetEntry {
        do {
            let allBudgets = try await databaseActor.fetch(FetchDescriptor<SpenDataModels.TransactionBudget>())
            let transactions = try await databaseActor.fetch(FetchDescriptor<SpenDataModels.Transaction>())
            
            let calendar = Calendar.current
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            
            var spentAmounts: [String: Double] = [:]
            
            let selectedBudgets = allBudgets.filter { budget in
                guard let category = budget.category,
                      budget.isActive,
                      budget.period == "Monthly",
                      let limit = budget.limit,
                      limit > 0 else { return false }
                
                return selectedBudgets.contains(category)
            }
            
            for budget in selectedBudgets {
                guard let category = budget.category else { continue }
                
                let categoryTransactions = transactions.filter { transaction in
                    transaction.category == category &&
                    transaction.date >= startOfMonth &&
                    transaction.date < endOfMonth
                }
                
                let spent = categoryTransactions.reduce(0.0) { $0 + abs($1.amount) }
                spentAmounts[category] = spent
            }
            
            return TransactionBudgetWidgetEntry(
                date: Date(),
                budgets: selectedBudgets,
                spentAmounts: spentAmounts,
                configuration: TwoBudgetsBarSelectionIntent()
            )
        } catch {
            print("Error creating entry: \(error)")
            return TransactionBudgetWidgetEntry(
                date: Date(),
                budgets: [],
                spentAmounts: [:],
                configuration: TwoBudgetsBarSelectionIntent()
            )
        }
    }
}

struct MediumBudgetBarWidget: Widget {
    let kind: String = "MediumBudgetBarWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TwoBudgetsBarSelectionIntent.self, provider: TwoBudgetsBarWidgetProvider()) { entry in
            MediumBudgetBarWidgetView(entry: entry)
                .containerBackground(Color.clear, for: .widget)
        }
        .configurationDisplayName("Two Budgets (Bar)")
        .description("Track two budgets' spending with progress bars.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    MediumBudgetBarWidget()
} timeline: {
    TransactionBudgetWidgetEntry(
        date: Date(),
        budgets: [
            SpenDataModels.TransactionBudget(
                category: "Groceries",
                limit: 500.0,
                period: "Monthly",
                startDate: Date()
            ),
            SpenDataModels.TransactionBudget(
                category: "Dining Out",
                limit: 300.0,
                period: "Monthly",
                startDate: Date()
            )
        ],
        spentAmounts: [
            "Groceries":20,
            "Dining Out": 800.0
        ],
        configuration: TwoBudgetsBarSelectionIntent(
            budget1: "Groceries",
            budget2: "Dining Out"
        )
    )
}
