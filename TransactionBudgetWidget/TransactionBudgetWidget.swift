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
                    let matches = budget.isActive && budget.period == "Monthly"
                    logger.debug("Budget \(budget.category ?? "nil"): isActive=\(budget.isActive), period=\(budget.period ?? "nil"), matches=\(matches)")
                    return matches
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

struct BudgetSelectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Budgets"
    static var description: LocalizedStringResource = "Choose which budgets to display in the widget"
    
    @Parameter(title: "Budget 1", optionsProvider: BudgetOptionsProvider())
    var budget1: String?
    
    @Parameter(title: "Budget 2", optionsProvider: BudgetOptionsProvider())
    var budget2: String?
    
    @Parameter(title: "Budget 3", optionsProvider: BudgetOptionsProvider())
    var budget3: String?
    
    @Parameter(title: "Budget 4", optionsProvider: BudgetOptionsProvider())
    var budget4: String?
    
    init() {}
    
    init(budget1: String? = nil, budget2: String? = nil, budget3: String? = nil, budget4: String? = nil) {
        self.budget1 = budget1
        self.budget2 = budget2
        self.budget3 = budget3
        self.budget4 = budget4
    }
}

struct TransactionBudgetWidgetEntry: TimelineEntry {
    let date: Date
    let budgets: [SpenDataModels.TransactionBudget]
    let spentAmounts: [String: Double]
    let configuration: BudgetSelectionIntent
}

struct TransactionBudgetWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = TransactionBudgetWidgetEntry
    typealias Intent = BudgetSelectionIntent
    
    private let databaseActor: DatabaseActor
    
    init() {
        self.databaseActor = DatabaseActor(container: SharedContainer.shared)
    }
    
    func placeholder(in context: Context) -> TransactionBudgetWidgetEntry {
        TransactionBudgetWidgetEntry(
            date: Date(),
            budgets: [],
            spentAmounts: [:],
            configuration: BudgetSelectionIntent()
        )
    }

    func snapshot(for configuration: BudgetSelectionIntent, in context: Context) async -> TransactionBudgetWidgetEntry {
        do {
            // Fetch all data
            let allBudgets = try await databaseActor.fetch(FetchDescriptor<SpenDataModels.TransactionBudget>())
            let transactions = try await databaseActor.fetch(FetchDescriptor<SpenDataModels.Transaction>())
            
            let calendar = Calendar.current
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            
            var spentAmounts: [String: Double] = [:]
            
            // Filter budgets based on configuration
            let selectedBudgets = allBudgets.filter { budget in
                guard let category = budget.category,
                      budget.isActive,
                      budget.period == "Monthly" else { return false }
                
                return [configuration.budget1, configuration.budget2, configuration.budget3, configuration.budget4].contains(category)
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
                configuration: configuration
            )
        } catch {
            print("Error in snapshot: \(error)")
            return TransactionBudgetWidgetEntry(
                date: Date(),
                budgets: [],
                spentAmounts: [:],
                configuration: configuration
            )
        }
    }

    func timeline(for configuration: BudgetSelectionIntent, in context: Context) async -> Timeline<TransactionBudgetWidgetEntry> {
        do {
            // Fetch all data
            let allBudgets = try await databaseActor.fetch(FetchDescriptor<SpenDataModels.TransactionBudget>())
            let transactions = try await databaseActor.fetch(FetchDescriptor<SpenDataModels.Transaction>())
            
            let calendar = Calendar.current
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            
            var spentAmounts: [String: Double] = [:]
            
            // Filter budgets based on configuration
            let selectedBudgets = allBudgets.filter { budget in
                guard let category = budget.category,
                      budget.isActive,
                      budget.period == "Monthly" else { return false }
                
                return [configuration.budget1, configuration.budget2, configuration.budget3, configuration.budget4].contains(category)
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
            
            let entry = TransactionBudgetWidgetEntry(
                date: Date(),
                budgets: selectedBudgets,
                spentAmounts: spentAmounts,
                configuration: configuration
            )
            
            let nextUpdate = Calendar.current.date(byAdding: .second, value: 5, to: Date())!
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        } catch {
            print("Error in timeline: \(error)")
            return Timeline(entries: [
                TransactionBudgetWidgetEntry(
                    date: Date(),
                    budgets: [],
                    spentAmounts: [:],
                    configuration: configuration
                )
            ], policy: .after(Date().addingTimeInterval(5))) // 5 seconds
        }
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
                
                let spent = entry.spentAmounts[budget.category ?? ""] ?? 0.0
                let limit = budget.limit ?? 0.0
                let progress = limit > 0.0 ? min(spent / limit, 1.0) : 0.0
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(progress > 1.0 ? Color.red : Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("$\(spent, specifier: "%.2f")")
                            .font(.caption2)
                            .bold()
                        Text("of")
                            .font(.caption2)
                        Text("$\(limit, specifier: "%.2f")")
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
                    
                    let spent = entry.spentAmounts[budget.category ?? ""] ?? 0.0
                    let limit = budget.limit ?? 0.0
                    let progress = limit > 0.0 ? min(spent / limit, 1.0) : 0.0
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(progress > 1.0 ? Color.red : Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        
                        VStack {
                            Text("$\(spent, specifier: "%.2f")")
                                .font(.caption2)
                                .bold()
                            Text("of")
                                .font(.caption2)
                            Text("$\(limit, specifier: "%.2f")")
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
                        let spent = entry.spentAmounts[budget.category ?? ""] ?? 0.0
                        let limit = budget.limit ?? 0.0
                        Text("$\(spent, specifier: "%.2f") / $\(limit, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    let spent = entry.spentAmounts[budget.category ?? ""] ?? 0.0
                    let limit = budget.limit ?? 0.0
                    let progress = limit > 0.0 ? min(spent / limit, 1.0) : 0.0
                    
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
        AppIntentConfiguration(kind: kind, intent: BudgetSelectionIntent.self, provider: TransactionBudgetWidgetProvider()) { entry in
            TransactionBudgetWidgetEntryView(entry: entry)
                .containerBackground(Color.clear, for: .widget)
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
        date: Date(),
        budgets: [],
        spentAmounts: [:],
        configuration: BudgetSelectionIntent()
    )
}

#Preview(as: .systemMedium) {
    TransactionBudgetWidget()
} timeline: {
    TransactionBudgetWidgetEntry(
        date: Date(),
        budgets: [],
        spentAmounts: [:],
        configuration: BudgetSelectionIntent()
    )
}

#Preview(as: .systemLarge) {
    TransactionBudgetWidget()
} timeline: {
    TransactionBudgetWidgetEntry(
        date: Date(),
        budgets: [],
        spentAmounts: [:],
        configuration: BudgetSelectionIntent()
    )
}
