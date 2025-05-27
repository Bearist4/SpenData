import Foundation
import Security

enum KeychainError: Error {
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
}

enum CloudKitError: Error {
    case recordNotFound
    case invalidData
} 