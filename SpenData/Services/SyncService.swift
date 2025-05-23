import Foundation
import CloudKit
import SwiftUI
import SwiftData

class SyncService: ObservableObject {
    static let shared = SyncService()
    private let container: CKContainer
    private let database: CKDatabase
    
    @Published var isSubscribed = false
    
    private init() {
        container = CKContainer.default()
        database = container.privateCloudDatabase
    }
    
    func setupSubscriptions() async {
        do {
            // First, check if we already have a subscription
            let existingSubscriptions = try await database.allSubscriptions()
            if existingSubscriptions.contains(where: { $0.subscriptionID == "bill-changes" }) {
                print("Subscription already exists")
                isSubscribed = true
                return
            }
            
            // Create a subscription for bill changes
            let subscription = CKQuerySubscription(
                recordType: "CD_Bill",
                predicate: NSPredicate(value: true),
                subscriptionID: "bill-changes",
                options: [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate]
            )
            
            // Configure notification
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            notificationInfo.shouldBadge = true
            notificationInfo.alertBody = "Bill data has been updated"
            subscription.notificationInfo = notificationInfo
            
            // Save the subscription
            try await database.save(subscription)
            isSubscribed = true
            
            // Request notification permissions
            await requestNotificationPermissions()
            
            print("Successfully set up CloudKit subscription")
        } catch {
            print("Failed to set up CloudKit subscription: \(error)")
        }
    }
    
    private func requestNotificationPermissions() async {
        do {
            let center = UNUserNotificationCenter.current()
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            try await center.requestAuthorization(options: options)
            
            // Register for remote notifications
            await UIApplication.shared.registerForRemoteNotifications()
            
            print("Successfully requested notification permissions")
        } catch {
            print("Failed to request notification permissions: \(error)")
        }
    }
    
    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        print("Received CloudKit notification: \(userInfo)")
        
        // Check if this is a CloudKit notification
        guard let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            print("Not a CloudKit notification")
            return
        }
        
        // Handle the notification based on its type
        switch ckNotification.notificationType {
        case .query:
            if let queryNotification = ckNotification as? CKQueryNotification {
                print("Received query notification for record: \(queryNotification.recordID?.recordName ?? "unknown")")
                // Trigger a sync
                Task {
                    await syncData()
                }
            }
        default:
            print("Unhandled notification type: \(ckNotification.notificationType)")
        }
    }
    
    func syncData() async {
        do {
            // Force a sync by triggering a CloudKit fetch
            try await container.accountStatus()
            
            // Notify that data has changed on main thread
            await MainActor.run {
                NotificationCenter.default.post(name: .billDataDidChange, object: nil)
            }
        } catch {
            print("Failed to sync data: \(error)")
        }
    }
}

// Notification name for bill data changes
extension Notification.Name {
    static let billDataDidChange = Notification.Name("billDataDidChange")
} 