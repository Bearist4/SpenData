//
//  SpenDataApp.swift
//  SpenData
//
//  Created by Benjamin CAILLET on 22.05.25.
//

import SwiftUI
import SwiftData
import UserNotifications
import AppIntents

extension Notification.Name {
    static let transactionDataDidChange = Notification.Name("transactionDataDidChange")
    static let financialGoalDataDidChange = Notification.Name("financialGoalDataDidChange")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Handle the notification
        SyncService.shared.handleNotification(userInfo)
        completionHandler(.newData)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Handle foreground notifications
        completionHandler([.banner, .sound])
    }
}

@main
struct SpenDataApp: App {
    let modelContainer: ModelContainer
    @StateObject private var syncService = SyncService.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        do {
            let schema = Schema([
                User.self,
                Transaction.self,
                Bill.self,
                BillBudget.self,
                TransactionBudget.self,
                Income.self,
                FinancialGoal.self,
                MonthlySpending.self
            ])
            
            // Configure CloudKit sync with proper options
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .identifier("group.com.spendata.container")
            )
            
            // Create a single container instance with error handling
            do {
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
                print("Successfully initialized ModelContainer with CloudKit sync")
            } catch {
                print("Failed to initialize ModelContainer with CloudKit: \(error)")
                
                // Fallback to local storage without CloudKit
                let localConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    groupContainer: .identifier("group.com.spendata.container")
                )
                
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [localConfig]
                )
                print("Successfully initialized ModelContainer with local storage")
            }
        } catch {
            print("Fatal error initializing ModelContainer: \(error)")
            
            // Last resort: in-memory configuration
            do {
                let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(
                    for: User.self, Bill.self, Transaction.self, BillBudget.self, 
                    TransactionBudget.self, Income.self, FinancialGoal.self, MonthlySpending.self,
                    configurations: inMemoryConfig
                )
                print("Successfully initialized in-memory ModelContainer")
            } catch {
                print("Fatal error details: \(error)")
                fatalError("Could not initialize ModelContainer: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                    User.self,
                    Transaction.self,
                    Bill.self,
                    BillBudget.self,
                    TransactionBudget.self,
                    Income.self,
                    FinancialGoal.self,
                    MonthlySpending.self
                ]) { result in
                    switch result {
                    case .success(let container):
                        // Configure CloudKit sync
                        Task {
                            await SyncService.shared.initializeSync()
                        }
                    case .failure(let error):
                        print("Failed to create model container: \(error)")
                    }
                }
        }
    }
}

// MARK: - App Shortcuts Provider
struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: LogTransactionIntent(),
                phrases: [
                    "Log transaction in ${applicationName}",
                    "Add transaction to ${applicationName}",
                    "Record transaction in ${applicationName}",
                    "Save transaction to ${applicationName}",
                    "Create transaction in ${applicationName}"
                ],
                shortTitle: "Log Transaction",
                systemImageName: "plus.circle"
            ),
            AppShortcut(
                intent: TestTransactionIntent(),
                phrases: [
                    "Test transaction in ${applicationName}",
                    "Create test transaction in ${applicationName}",
                    "Simulate transaction in ${applicationName}"
                ],
                shortTitle: "Test Transaction",
                systemImageName: "creditcard"
            )
        ]
    }
}
