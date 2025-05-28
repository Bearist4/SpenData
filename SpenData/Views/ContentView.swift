import SwiftUI
import SwiftData

struct MainTabView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
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
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var user: [User]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var syncService = SyncService.shared
    @State private var isLoading = true
    @State private var selectedTab = 0
    
    init(){
        UITabBar.appearance().backgroundColor = .white
    }
    
    var body: some View {
        NavigationStack {
            MainTabView(selectedTab: $selectedTab)
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
                    try? modelContext.save()
                }
                .onChange(of: syncService.syncState) { oldState, newState in
                    // Only save if we're not in an error state
                    if case .idle = newState {
                        try? modelContext.save()
                    }
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.createPreviewContainer())
}
