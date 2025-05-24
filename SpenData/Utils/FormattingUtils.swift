import Foundation
import SwiftUI

enum FormattingUtils {
    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter
    }()
    
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        return formatter
    }()
    
    static func formatCurrency(_ amount: Double) -> String {
        return currencyFormatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    static func formatNumber(_ number: Double) -> String {
        return numberFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    static func parseCurrency(_ string: String) -> Double? {
        return currencyFormatter.number(from: string)?.doubleValue
    }
    
    static func parseNumber(_ string: String) -> Double? {
        return numberFormatter.number(from: string)?.doubleValue
    }
} 