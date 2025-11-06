import Foundation
import SwiftCardanoCore
@preconcurrency import Noora

let noora = Noora(theme: Style.theme, content: Style.content)

func spacedPrint(_ text: TerminalText) {
    print(
        noora.format(text),
        terminator: "\n\n"
    )
}

public func lovelaceToAda(_ lovelace: UInt64) -> Double {
    return Double(lovelace) / 1_000_000.0
}

public func lovelaceToAdaString(_ lovelace: UInt64) -> String {
    let adaValue = lovelaceToAda(lovelace)
    return String(format: "%.6f ₳", adaValue)
}

public func lovelaceToAdaFormatString(_ lovelace: UInt64, numDecimals: Int = 2) -> String {
    let adaValue = lovelaceToAda(lovelace)
    return formatNumber(adaValue, numDecimals: numDecimals)
}

public func formatNumber(_ value: Any?, numDecimals: Int = 2) -> String {
    // Normalize nil / empty string
    if value == nil { return "0 ₳" }
    if let s = value as? String, s.isEmpty { return "0 ₳" }
    
    // Convert to Decimal
    let decimalValue: Decimal
    if let s = value as? String, let d = Decimal(string: s) {
        decimalValue = d
    } else if let i = value as? Int {
        decimalValue = Decimal(i)
    } else if let d = value as? Double {
        decimalValue = Decimal(d)
    } else if let dec = value as? Decimal {
        decimalValue = dec
    } else {
        return "0 ₳"
    }
    
    // Determine integer-truncated value for threshold decisions
    let absValue = abs(decimalValue)
    
    // Convert to Int64 for threshold comparison using string conversion
    let intValue: Int64
    if let int64 = Int64(absValue.description.split(separator: ".").first ?? "0") {
        intValue = int64
    } else {
        intValue = 0
    }
    
    // Helper to format scaled values and trim trailing zeros/dot
    func formatScaled(_ scaled: Decimal, suffix: String) -> String {
        let str = formatDecimal(scaled, decimals: numDecimals, trimZeros: true)
        return str + suffix
    }
    
    // Helper to format a Decimal to string with specified decimals
    func formatDecimal(_ value: Decimal, decimals: Int, trimZeros: Bool) -> String {
        let sign = value.isSignMinus ? "-" : ""
        let absVal = abs(value)
        
        // Split into whole and fractional parts
        let parts = absVal.description.split(separator: ".", maxSplits: 1)
        let wholePart = String(parts.first ?? "0")
        
        if decimals == 0 {
            // Round to nearest integer
            let next = Decimal(string: String(parts.count > 1 ? parts[1].prefix(1) : "0")) ?? 0
            if next >= 5 {
                return sign + String((Int64(wholePart) ?? 0) + 1)
            }
            return sign + wholePart
        }
        
        // Get fractional part and pad/trim to desired decimals
        var fracPart = parts.count > 1 ? String(parts[1]) : ""
        
        // Pad with zeros if needed
        while fracPart.count < decimals {
            fracPart += "0"
        }
        
        // Round if we have more digits than needed
        if fracPart.count > decimals {
            let keepDigits = fracPart.prefix(decimals)
            let roundDigit = Int(String(fracPart.dropFirst(decimals).prefix(1))) ?? 0
            
            if roundDigit >= 5 {
                // Need to round up
                let fracValue = (Int(keepDigits) ?? 0) + 1
                let maxValue = Int(pow(10.0, Double(decimals)))
                
                if fracValue >= maxValue {
                    // Carry to whole part
                    let newWhole = (Int64(wholePart) ?? 0) + 1
                    fracPart = String(repeating: "0", count: decimals)
                    return sign + String(newWhole) + "." + fracPart
                } else {
                    // Left-pad with zeros
                    var padded = String(fracValue)
                    while padded.count < decimals {
                        padded = "0" + padded
                    }
                    fracPart = padded
                }
            } else {
                fracPart = String(keepDigits)
            }
        }
        
        // Trim trailing zeros if requested
        if trimZeros {
            while fracPart.last == "0" {
                fracPart.removeLast()
            }
            if fracPart.isEmpty {
                return sign + wholePart
            }
        }
        
        return sign + wholePart + "." + fracPart
    }
    
    let result: String
    if intValue < 1000 {
        // Fixed number of decimals
        result = formatDecimal(decimalValue, decimals: numDecimals, trimZeros: false) + " ₳"
    } else if intValue < 1_000_000 {
        result = formatScaled(decimalValue / Decimal(1_000), suffix: "K ₳")
        return result
    } else if intValue < 1_000_000_000 {
        result = formatScaled(decimalValue / Decimal(1_000_000), suffix: "M ₳")
        return result
    } else {
        result = formatScaled(decimalValue / Decimal(1_000_000_000), suffix: "B ₳")
        return result
    }
    
    return result
}
