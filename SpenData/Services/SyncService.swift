import Foundation
import CloudKit
import SwiftUI
import SwiftData
import os.log
import CoreData

class SyncService: ObservableObject {
    static let shared = SyncService()
    private let container: CKContainer
    private let database: CKDatabase
    private let logger = Logger(subsystem: "com.spendata.sync", category: "SyncService")
    
    @Published var isSubscribed = false
    @Published var syncState: SyncState = .idle
    @Published var isInitialized = false
    private var syncInProgress = false
    private var isCleaningUp = false
    private var lastSyncAttempt: Date?
    private let minimumSyncInterval: TimeInterval = 5.0 // 5 seconds between sync attempts
    private var syncTask: Task<Void, Never>?
    
    enum SyncState: Equatable {
        case idle
        case syncing
        case resetting
        case error(String)
        
        static func == (lhs: SyncState, rhs: SyncState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.syncing, .syncing),
                 (.resetting, .resetting):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    private init() {
        // Verify the container identifier matches the one in your app's entitlements
        self.container = CKContainer(identifier: "iCloud.Bearista.SpenData")
        self.database = container.privateCloudDatabase
        
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
        
        // Set up observer for app entering background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppEnteredBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func handleAppBecameActive() {
        // Add delay between sync attempts during testing
        if let lastAttempt = lastSyncAttempt {
            let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
            if timeSinceLastAttempt < minimumSyncInterval {
                logger.info("Skipping sync on app active - too soon since last attempt (\(timeSinceLastAttempt) seconds)")
                return
            }
        }
        
        Task {
            await initializeSync()
        }
    }
    
    @objc private func handleAppEnteredBackground() {
        Task {
            await cleanupSync()
        }
    }
    
    private func cleanupSync() async {
        // Prevent multiple cleanup operations
        guard !isCleaningUp else { return }
        isCleaningUp = true
        defer { isCleaningUp = false }
        
        logger.info("Cleaning up sync state")
        
        // Cancel any existing sync task
        syncTask?.cancel()
        syncTask = nil
        
        do {
            // Remove existing subscriptions
            let subscriptions = try await database.allSubscriptions()
            for subscription in subscriptions {
                try await database.deleteSubscription(withID: subscription.subscriptionID)
            }
            
            // Reset sync state
            await MainActor.run {
                isSubscribed = false
                isInitialized = false
                syncState = .idle
                syncInProgress = false
            }
            
            // Wait a bit to ensure all CloudKit operations are complete
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            logger.info("Successfully cleaned up sync state")
        } catch {
            logger.error("Failed to clean up sync state: \(error.localizedDescription)")
        }
    }
    
    func initializeSync() async {
        // Cancel any existing sync task
        syncTask?.cancel()
        
        // Create a new sync task
        syncTask = Task {
            // Prevent multiple initialization attempts
            guard !isInitialized && !syncInProgress else { return }
            
            // Add delay between sync attempts during testing
            if let lastAttempt = lastSyncAttempt {
                let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
                if timeSinceLastAttempt < minimumSyncInterval {
                    logger.info("Skipping sync - too soon since last attempt (\(timeSinceLastAttempt) seconds)")
                    try? await Task.sleep(nanoseconds: UInt64((minimumSyncInterval - timeSinceLastAttempt) * 1_000_000_000))
                }
            }
            lastSyncAttempt = Date()
            
            logger.info("Initializing sync")
            await MainActor.run {
                syncState = .syncing
                syncInProgress = true
            }
            
            do {
                // Check CloudKit availability
                let status = try await container.accountStatus()
                switch status {
                case .available:
                    break
                case .noAccount:
                    logger.error("No iCloud account found")
                    await MainActor.run {
                        syncState = .error("Please sign in to iCloud in Settings")
                        syncInProgress = false
                    }
                    return
                case .restricted:
                    logger.error("iCloud access is restricted")
                    await MainActor.run {
                        syncState = .error("iCloud access is restricted")
                        syncInProgress = false
                    }
                    return
                case .couldNotDetermine:
                    logger.error("Could not determine iCloud status")
                    await MainActor.run {
                        syncState = .error("Could not determine iCloud status")
                        syncInProgress = false
                    }
                    return
                @unknown default:
                    logger.error("Unknown iCloud status: \(status.rawValue)")
                    await MainActor.run {
                        syncState = .error("Unknown iCloud status")
                        syncInProgress = false
                    }
                    return
                }
                
                // Verify container configuration
                do {
                    _ = try await container.containerIdentifier
                } catch {
                    logger.error("Failed to get container configuration: \(error.localizedDescription)")
                    await MainActor.run {
                        syncState = .error("Please check your iCloud settings and try again")
                        syncInProgress = false
                    }
                    return
                }
                
                // Clean up any existing sync state before initializing
                await cleanupSync()
                
                // Wait a bit to ensure cleanup is complete
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Set up notifications
                await setupSubscriptions()
                
                // Handle schema migration if needed
                do {
                    try await handleSchemaMigration()
                } catch {
                    logger.error("Failed to handle schema migration: \(error.localizedDescription)")
                    // If we get an error here, try to recreate the zone
                    try await recreateZone()
                }
                
                await MainActor.run {
                    isInitialized = true
                    syncState = .idle
                    syncInProgress = false
                }
                
                logger.info("Sync initialization completed")
            } catch {
                logger.error("Failed to initialize sync: \(error.localizedDescription)")
                await MainActor.run {
                    syncState = .error("Failed to initialize sync: \(error.localizedDescription)")
                    syncInProgress = false
                }
                
                // Attempt recovery after a delay
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await initializeSync()
            }
        }
        
        // Wait for the sync task to complete
        await syncTask?.value
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
            if let ckError = error as? CKError {
                switch ckError.code {
                case .zoneNotFound:
                    logger.info("Zone not found, creating new zone")
                    try await recreateZone()
                case .serverRecordChanged:
                    logger.info("Server record changed, recreating zone")
                    try await recreateZone()
                default:
                    logger.error("Error checking schema migration: \(error.localizedDescription)")
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
            
            // Get the reason for the reset
            if let reason = notification.userInfo?["reason"] as? String {
                logger.info("Sync reset reason: \(reason)")
            }
            
            // Attempt to recover from sync reset
            do {
                // Wait a short time to ensure the reset is complete
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // 2 seconds
                
                // Force reset the sync state
                await forceResetSync()
                
                // Re-initialize sync
                await initializeSync()
                
                // If we get here, the recovery was successful
                syncState = .idle
                isInitialized = true
                logger.info("Successfully recovered from sync reset")
            } catch {
                logger.error("Failed to recover from sync reset: \(error.localizedDescription)")
                syncState = .error("Failed to recover from sync reset: \(error.localizedDescription)")
            }
        }
    }
    
    private func forceResetSync() async {
        logger.info("Forcing sync reset")
        
        do {
            // First clean up existing sync state
            await cleanupSync()
            
            // Delete the existing zone
            let recordZone = CKRecordZone(zoneName: "com.spendata.default")
            try await database.deleteRecordZone(withID: recordZone.zoneID)
            
            // Create a new zone
            try await database.save(recordZone)
            
            // Clear local cache on main thread
            await MainActor.run {
                if let modelContainer = try? ModelContainer(for: User.self, Transaction.self, Bill.self, BillBudget.self, 
                                                          TransactionBudget.self, Income.self, FinancialGoal.self, MonthlySpending.self) {
                    try? modelContainer.mainContext.save()
                }
            }
            
            logger.info("Successfully reset sync state")
        } catch {
            logger.error("Failed to force reset sync: \(error.localizedDescription)")
        }
    }
    
    @objc private func handleSyncResetComplete(_ notification: Notification) {
        logger.info("Sync reset completed")
        Task { @MainActor in
            // Re-initialize sync after reset
            do {
                await initializeSync()
                syncState = .idle
                isInitialized = true
                logger.info("Successfully re-initialized sync after reset")
            } catch {
                logger.error("Failed to re-initialize sync after reset: \(error.localizedDescription)")
                syncState = .error("Failed to re-initialize sync. Please try again later.")
            }
        }
    }
    
    func setupSubscriptions() async {
        do {
            logger.info("Setting up CloudKit subscriptions")
            // First, check if we already have a subscription
            let existingSubscriptions = try await database.allSubscriptions()
            if existingSubscriptions.contains(where: { $0.subscriptionID == "user-data-changes" }) {
                logger.info("Subscription already exists")
                await MainActor.run {
                    isSubscribed = true
                }
                return
            }
            
            // Create a subscription for user data changes
            let subscription = CKQuerySubscription(
                recordType: "SecureData",
                predicate: NSPredicate(value: true),
                subscriptionID: "user-data-changes",
                options: [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate]
            )
            
            // Configure notification
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            notificationInfo.shouldBadge = true
            notificationInfo.alertBody = "User data has been updated"
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
        guard isInitialized, !syncInProgress else { return }
        
        syncInProgress = true
        defer { syncInProgress = false }
        
        await MainActor.run {
            syncState = .syncing
        }
        
        do {
            // Check CloudKit availability
            let status = try await container.accountStatus()
            guard status == .available else {
                
                return
            }
            
            // Fetch changes from CloudKit
            let zoneID = CKRecordZone.ID(zoneName: "com.spendata.default", ownerName: CKCurrentUserDefaultName)
            
            // Create a query for SecureData records
            let query = CKQuery(recordType: "SecureData", predicate: NSPredicate(value: true))
            
            // Fetch records using the query
            let (results, _) = try await database.records(matching: query)
            
            // Process the results
            for (recordID, result) in results {
                do {
                    let record = try result.get()
                    self.logger.info("Processing record: \(recordID.recordName)")
                    await handleRecordChange(record)
                } catch {
                    self.logger.error("Failed to process record \(recordID.recordName): \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                syncState = .idle
            }
            
            self.logger.info("Sync completed successfully")
        } catch {
            self.logger.error("Sync failed: \(error.localizedDescription)")
            await MainActor.run {
                syncState = .error("Sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleRecordChange(_ record: CKRecord) async {
        do {
            // Save the record to the database
            try await database.save(record)
            logger.info("Successfully saved changed record: \(record.recordID.recordName)")
            
            // Notify that data has changed
            await MainActor.run {
                NotificationCenter.default.post(name: .transactionDataDidChange, object: nil)
            }
        } catch {
            logger.error("Failed to save changed record: \(error.localizedDescription)")
        }
    }
    
    private func handleRecordDeletion(_ recordID: CKRecord.ID, recordType: String) async {
        do {
            // Delete the record from the database
            try await database.deleteRecord(withID: recordID)
            logger.info("Successfully deleted record: \(recordID.recordName)")
            
            // Notify that data has changed
            await MainActor.run {
                NotificationCenter.default.post(name: .transactionDataDidChange, object: nil)
            }
        } catch {
            logger.error("Failed to delete record: \(error.localizedDescription)")
        }
    }
    
    private func resolveConflict() async {
        logger.info("Resolving conflict")
        do {
            try await container.accountStatus()
            await MainActor.run {
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
    
    private func recreateZone() async throws {
        logger.info("Recreating zone")
        
        // First ensure we're not in the middle of a sync
        await cleanupSync()
        
        do {
            // Delete the existing zone if it exists
            let recordZone = CKRecordZone(zoneName: "com.spendata.default")
            do {
                try await database.deleteRecordZone(withID: recordZone.zoneID)
            } catch {
                // Ignore errors when deleting the zone
                logger.info("No existing zone to delete")
            }
            
            // Wait a bit to ensure zone deletion is complete
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Create a new zone
            try await database.save(recordZone)
            
            // Clear local cache and reset persistent history
            await MainActor.run {
                if let modelContainer = try? ModelContainer(for: User.self, Transaction.self, Bill.self, BillBudget.self, 
                                                          TransactionBudget.self, Income.self, FinancialGoal.self, MonthlySpending.self) {
                    do {
                        // Clear all objects from the context
                        try modelContainer.mainContext.delete(model: User.self)
                        try modelContainer.mainContext.delete(model: Transaction.self)
                        try modelContainer.mainContext.delete(model: Bill.self)
                        try modelContainer.mainContext.delete(model: BillBudget.self)
                        try modelContainer.mainContext.delete(model: TransactionBudget.self)
                        try modelContainer.mainContext.delete(model: Income.self)
                        try modelContainer.mainContext.delete(model: FinancialGoal.self)
                        try modelContainer.mainContext.delete(model: MonthlySpending.self)
                        
                        // Save the context
                        try modelContainer.mainContext.save()
                        
                        // Post notification to trigger a full sync
                        NotificationCenter.default.post(name: .billDataDidChange, object: nil)
                    } catch {
                        logger.error("Failed to clear persistent history: \(error.localizedDescription)")
                    }
                }
            }
            
            logger.info("Zone recreated successfully")
        } catch {
            logger.error("Failed to recreate zone: \(error.localizedDescription)")
            throw error
        }
    }
}

// Notification name for bill data changes
extension Notification.Name {
    static let billDataDidChange = Notification.Name("billDataDidChange")
} 

