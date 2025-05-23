//
//  SpenDataApp.swift
//  SpenData
//
//  Created by Benjamin CAILLET on 22.05.25.
//

import SwiftUI
import SwiftData
import UserNotifications

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
            // Create schema with our models
            let schema = Schema([
                User.self,
                Bill.self
            ])
            
            // Configure for CloudKit
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .private("iCloud.Bearista.SpenData")
            )
            
            // Initialize container
            modelContainer = try ModelContainer(
                for: schema,
                configurations: config
            )
            
            print("Successfully initialized ModelContainer with CloudKit")
            
        } catch {
            print("ModelContainer initialization error: \(error)")
            
            // Try with in-memory configuration
            do {
                let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                modelContainer = try ModelContainer(
                    for: User.self, Bill.self,
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
            WelcomeView()
                .onReceive(NotificationCenter.default.publisher(for: .billDataDidChange)) { _ in
                    // Refresh the view when bill data changes
                    try? modelContainer.mainContext.save()
                }
                .task {
                    // Set up CloudKit sync after view appears
                    await syncService.setupSubscriptions()
                }
                .refreshable {
                    // Pull to refresh
                    await syncService.syncData()
                }
        }
        .modelContainer(modelContainer)
    }
}
