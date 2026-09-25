import Foundation
import CallKit

public struct PhoneNumberRange: Comparable {
    public let start: Int64
    public let end: Int64
    
    public static func < (lhs: PhoneNumberRange, rhs: PhoneNumberRange) -> Bool {
        return lhs.start < rhs.start
    }
}

public class PhoneNumberGenerator {
    
    /// Chuyển đổi các quy tắc prefix thành các dải số điện thoại (Ranges)
    public static func generateRanges(from rules: [BlockPrefixRule]) -> [PhoneNumberRange] {
        var rawRanges: [PhoneNumberRange] = []
        
        for rule in rules where rule.isEnabled {
            var prefixStr = rule.prefix.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Xử lý mã quốc gia và số 0 ở đầu
            var countryCode = rule.countryCode.replacingOccurrences(of: "+", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if countryCode.isEmpty {
                countryCode = "84" // Mặc định Việt Nam
            }
            
            // Nếu prefix bắt đầu bằng 0 (ví dụ 059) và country code là 84 -> chuyển thành 8459
            if prefixStr.hasPrefix("0") {
                prefixStr = String(prefixStr.dropFirst())
            }
            
            let fullPrefix = countryCode + prefixStr
            let currentPrefixLength = fullPrefix.count
            
            // Tính số chữ số còn lại cần sinh
            // Ví dụ: tổng độ dài 10 chữ số (059xxxxxxx), sau khi đổi 0 -> 84 thì độ dài là 11 ký tự (8459xxxxxxx)
            let targetLength = rule.totalDigits - 1 + countryCode.count
            let remainingDigitsCount = targetLength - currentPrefixLength
            
            guard remainingDigitsCount >= 0 else { continue }
            
            if remainingDigitsCount == 0 {
                // Số chính xác đơn lẻ
                if let singleNumber = Int64(fullPrefix) {
                    rawRanges.append(PhoneNumberRange(start: singleNumber, end: singleNumber))
                }
            } else {
                // Dải số từ 000...0 đến 999...9
                let multiplier = Int64(pow(10.0, Double(remainingDigitsCount)))
                if let baseNumber = Int64(fullPrefix) {
                    let startNumber = baseNumber * multiplier
                    let endNumber = startNumber + (multiplier - 1)
                    rawRanges.append(PhoneNumberRange(start: startNumber, end: endNumber))
                }
            }
        }
        
        // Sắp xếp và hợp nhất các dải bị giao nhau (merge overlapping ranges)
        return mergeRanges(rawRanges.sorted())
    }
    
    /// Hợp nhất các dải số liên tiếp hoặc chồng lấn để tối ưu và đảm bảo thứ tự tăng dần
    private static func mergeRanges(_ sortedRanges: [PhoneNumberRange]) -> [PhoneNumberRange] {
        guard !sortedRanges.isEmpty else { return [] }
        
        var merged: [PhoneNumberRange] = []
        var current = sortedRanges[0]
        
        for i in 1..<sortedRanges.count {
            let next = sortedRanges[i]
            if next.start <= current.end + 1 {
                // Chồng lấn hoặc nối tiếp nhau -> Hợp nhất
                current = PhoneNumberRange(start: current.start, end: max(current.end, next.end))
            } else {
                merged.append(current)
                current = next
            }
        }
        merged.append(current)
        return merged
    }
}
