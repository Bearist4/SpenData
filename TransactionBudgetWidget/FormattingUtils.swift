import Foundation

enum CurrencySymbolPlacement {
    case prefix
    case suffix
}

struct CurrencyUtils {
    static func symbolPlacement(for locale: Locale = .current) -> CurrencySymbolPlacement {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        let testValue = 1.0
        let formatted = formatter.string(from: NSNumber(value: testValue)) ?? ""
        let symbol = formatter.currencySymbol ?? ""
        if formatted.hasPrefix(symbol) {
            return .prefix
        } else if formatted.hasSuffix(symbol) {
            return .suffix
        } else {
            // Fallback: default to prefix
            return .prefix
        }
    }
} 