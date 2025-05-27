import Foundation
import CloudKit
import SwiftUI
import SwiftData
import os.log

class SyncService: ObservableObject {
    static let shared = SyncService()
    private let container: CKContainer
    private let database: CKDatabase
    private let logger = Logger(subsystem: "com.spendata.sync", category: "SyncService")
    
    @Published var isSubscribed = false
    @Published var syncState: SyncState = .idle
    @Published var isInitialized = false
    
    enum SyncState {
        case idle
        case syncing
        case resetting
        case error(String)
    }
    
    private init() {
        container = CKContainer.default()
        database = container.privateCloudDatabase
        
        // Set up notification observers for sync reset
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncReset(_:)),
            name: NSNotification.Name("NSCloudKitMirroringDelegateWillResetSyncNotificationName"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncResetComplete(_:)),
            name: NSNotification.Name("NSCloudKitMirroringDelegateDidResetSyncNotificationName"),
            object: nil
        )
        
        // Set up observer for app becoming active
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppBecameActive() {
        Task {
            await initializeSync()
        }
    }
    
    func initializeSync() async {
        guard !isInitialized else { return }
        
        logger.info("Initializing sync")
        await MainActor.run {
            syncState = .syncing
        }
        
        do {
            // First check if we're logged into iCloud
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                logger.error("iCloud account not available: \(accountStatus.rawValue)")
                await MainActor.run {
                    syncState = .error("iCloud account not available")
                }
                return
            }
            
            // Set up subscriptions
            await setupSubscriptions()
            
            // Perform initial sync
            try await container.accountStatus()
            
            // Handle schema migration if needed
            try await handleSchemaMigration()
            
            await MainActor.run {
                isInitialized = true
                syncState = .idle
            }
            
            logger.info("Sync initialization completed")
        } catch {
            logger.error("Failed to initialize sync: \(error.localizedDescription)")
            await MainActor.run {
                syncState = .error("Failed to initialize sync: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleSchemaMigration() async throws {
        logger.info("Checking for schema migration")
        
        do {
            // Check if we need to migrate the schema
            let recordZone = CKRecordZone(zoneName: "com.spendata.default")
            let zoneID = recordZone.zoneID
            
            // Try to fetch the zone
            _ = try await database.recordZone(for: zoneID)
            
            // If we get here, the zone exists and we don't need to migrate
            logger.info("No schema migration needed")
            return
        } catch {
            if let ckError = error as? CKError, ckError.code == .zoneNotFound {
                logger.info("Zone not found, creating new zone")
                
                do {
                    // Create a new zone
                    let recordZone = CKRecordZone(zoneName: "com.spendata.default")
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        database.save(recordZone) { zone, error in
                            if let error = error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume(returning: ())
                            }
                        }
                    }
                    
                    // Post notification to trigger a full sync
                    await MainActor.run {
                        NotificationCenter.default.post(name: .billDataDidChange, object: nil)
                    }
                    
                    logger.info("New zone created and sync triggered")
                } catch {
                    logger.error("Failed to create new zone: \(error.localizedDescription)")
                    throw error
                }
            } else {
                logger.error("Error checking schema migration: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    @objc private func handleSyncReset(_ notification: Notification) {
        logger.info("Sync reset starting")
        Task { @MainActor in
            syncState = .resetting
            isInitialized = false
        }
    }
    
    @objc private func handleSyncResetComplete(_ notification: Notification) {
        logger.info("Sync reset completed")
        Task { @MainActor in
            // Re-initialize sync after reset
            await initializeSync()
        }
    }
    
    func setupSubscriptions() async {
        do {
            logger.info("Setting up CloudKit subscriptions")
            // First, check if we already have a subscription
            let existingSubscriptions = try await database.allSubscriptions()
            if existingSubscriptions.contains(where: { $0.subscriptionID == "bill-changes" }) {
                logger.info("Subscription already exists")
                await MainActor.run {
                    isSubscribed = true
                }
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
            
            await MainActor.run {
                isSubscribed = true
            }
            
            // Request notification permissions
            await requestNotificationPermissions()
            
            logger.info("Successfully set up CloudKit subscription")
        } catch {
            logger.error("Failed to set up CloudKit subscription: \(error.localizedDescription)")
        }
    }
    
    private func requestNotificationPermissions() async {
        do {
            let center = UNUserNotificationCenter.current()
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            try await center.requestAuthorization(options: options)
            
            // Register for remote notifications
            await UIApplication.shared.registerForRemoteNotifications()
            
            logger.info("Successfully requested notification permissions")
        } catch {
            logger.error("Failed to request notification permissions: \(error.localizedDescription)")
        }
    }
    
    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        logger.info("Received CloudKit notification")
        
        // Check if this is a CloudKit notification
        guard let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            logger.error("Not a CloudKit notification")
            return
        }
        
        // Handle the notification based on its type
        switch ckNotification.notificationType {
        case .query:
            if let queryNotification = ckNotification as? CKQueryNotification {
                logger.info("Received query notification for record: \(queryNotification.recordID?.recordName ?? "unknown")")
                // Trigger a sync
                Task {
                    await syncData()
                }
            }
        default:
            logger.error("Unhandled notification type: \(ckNotification.notificationType.rawValue)")
        }
    }
    
    func syncData() async {
        guard isInitialized else {
            logger.info("Sync not initialized, initializing first")
            await initializeSync()
            return
        }
        
        do {
            logger.info("Starting sync")
            await MainActor.run {
                syncState = .syncing
            }
            
            // Force a sync by triggering a CloudKit fetch
            try await container.accountStatus()
            
            // Notify that data has changed on main thread
            await MainActor.run {
                NotificationCenter.default.post(name: .billDataDidChange, object: nil)
                syncState = .idle
            }
            
            logger.info("Sync completed successfully")
        } catch {
            logger.error("Failed to sync data: \(error.localizedDescription)")
            
            await MainActor.run {
                syncState = .error(error.localizedDescription)
            }
            
            // Handle specific CloudKit errors
            if let cloudKitError = error as? CKError {
                switch cloudKitError.code {
                case .serverRecordChanged:
                    logger.info("Server record changed, attempting to resolve conflict")
                    await resolveConflict()
                case .zoneNotFound:
                    logger.info("Zone not found, attempting to recreate zone")
                    await recreateZone()
                case .networkFailure, .networkUnavailable:
                    logger.error("Network issue detected")
                    // You might want to implement a retry mechanism here
                default:
                    logger.error("Unhandled CloudKit error: \(cloudKitError.localizedDescription)")
                }
            }
        }
    }
    
    private func resolveConflict() async {
        logger.info("Resolving conflict")
        do {
            try await container.accountStatus()
            await MainActor.run {
                NotificationCenter.default.post(name: .billDataDidChange, object: nil)
                syncState = .idle
            }
            logger.info("Conflict resolved successfully")
        } catch {
            logger.error("Failed to resolve conflict: \(error.localizedDescription)")
            await MainActor.run {
                syncState = .error("Failed to resolve conflict: \(error.localizedDescription)")
            }
        }
    }
    
    private func recreateZone() async {
        logger.info("Recreating zone")
        do {
            try await container.accountStatus()
            await MainActor.run {
                NotificationCenter.default.post(name: .billDataDidChange, object: nil)
                syncState = .idle
            }
            logger.info("Zone recreated successfully")
        } catch {
            logger.error("Failed to recreate zone: \(error.localizedDescription)")
            await MainActor.run {
                syncState = .error("Failed to recreate zone: \(error.localizedDescription)")
            }
        }
    }
}

// Notification name for bill data changes
extension Notification.Name {
    static let billDataDidChange = Notification.Name("billDataDidChange")
} 