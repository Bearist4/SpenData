import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var user: [User]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var syncService = SyncService.shared
    @State private var isLoading = true
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading || !syncService.isInitialized {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading your data...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .task {
                        await loadData()
                    }
                } else if let currentUser = user.first {
                    TabView(selection: $selectedTab) {
                        DashboardView()
                            .tabItem {
                                Label("Dashboard", systemImage: "chart.pie.fill")
                            }
                        
                        TransactionsView()
                            .tabItem {
                                Label("Transactions", systemImage: "list.bullet")
                            }
                        
                        BudgetsView()
                            .tabItem {
                                Label("Budgets", systemImage: "dollarsign.circle.fill")
                            }
                        
                        SettingsView()
                            .tabItem {
                                Label("Settings", systemImage: "gear")
                            }
                    }
                    .toolbar {
                        #if DEBUG
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Debug Spending") {
                                Task {
                                    await MonthlySpendingService.shared.calculateAndStoreMonthlySpending(modelContext: modelContext)
                                    MonthlySpendingService.shared.printCurrentMonthSpending(modelContext: modelContext)
                                }
                            }
                        }
                        #endif
                    }
                } else {
                    VStack {
                        Text("No user data found")
                            .font(.headline)
                        Text("Please sign out and sign in again")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .transactionDataDidChange)) { _ in
                // Refresh the view when transaction data changes
                try? modelContext.save()
            }
            .task {
                // Set up CloudKit sync after view appears
                await syncService.setupSubscriptions()
                // Run migration for existing data
                await FinancialGoal.migrateExistingData(modelContext: modelContext)
            }
            .refreshable {
                // Pull to refresh
                await syncService.syncData()
            }
        }
    }
    
    private func loadData() async {
        guard let currentUser = user.first else { return }
        
        do {
            // Load secure data
            try await currentUser.loadSecureData()
            
            // Initialize sync
            await syncService.initializeSync()
            
            // Update last login date
            currentUser.updateLastLoginDate()
            
            // Save changes
            try modelContext.save()
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            print("Error loading data: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.createPreviewContainer())
}
