import Foundation
import CallKit

public struct PhoneNumberRange: Comparable, Equatable {
    public let start: Int64
    public let end: Int64
    
    public init(start: Int64, end: Int64) {
        self.start = start
        self.end = end
    }
    
    public static func < (lhs: PhoneNumberRange, rhs: PhoneNumberRange) -> Bool {
        return lhs.start < rhs.start
    }
}

public class PhoneNumberGenerator {
    
    // Giới hạn số lượng bản ghi tối đa cho 1 quy tắc để không làm tràn RAM CallKit của iOS
    private static let maxNumbersPerRange: Int64 = 1_000_000
    
    /// Chuyển đổi các quy tắc prefix thành các dải số điện thoại (Ranges)
    public static func generateRanges(from rules: [BlockPrefixRule]) -> [PhoneNumberRange] {
        var rawRanges: [PhoneNumberRange] = []
        
        for rule in rules where rule.isEnabled {
            var prefixStr = rule.prefix.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prefixStr.isEmpty else { continue }
            
            // Xử lý mã quốc gia và số 0 ở đầu
            var countryCode = rule.countryCode.replacingOccurrences(of: "+", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            if countryCode.isEmpty {
                countryCode = "84" // Mặc định Việt Nam
            }
            
            if prefixStr.hasPrefix("0") {
                prefixStr = String(prefixStr.dropFirst())
            }
            
            // Nếu người dùng nhập đầu số 3 chữ số như "059" (59), tự động mở rộng thành các dải 4 chữ số thực tế (592, 593, 598, 599,...) để tối ưu bộ nhớ
            var prefixesToProcess: [String] = []
            if prefixStr == "59" {
                prefixesToProcess = ["592", "593", "598", "599", "590", "591", "594", "595", "596", "597"]
            } else {
                prefixesToProcess = [prefixStr]
            }
            
            for p in prefixesToProcess {
                let fullPrefix = countryCode + p
                let currentPrefixLength = fullPrefix.count
                
                // Độ dài số điện thoại chuẩn quốc tế (không tính dấu +)
                // Ví dụ VN 10 số: 059 812 3456 -> 84 59 812 3456 (11 chữ số)
                let targetLength = rule.totalDigits - 1 + countryCode.count
                let remainingDigitsCount = targetLength - currentPrefixLength
                
                guard remainingDigitsCount >= 0 else { continue }
                
                if remainingDigitsCount == 0 {
                    if let singleNumber = Int64(fullPrefix) {
                        rawRanges.append(PhoneNumberRange(start: singleNumber, end: singleNumber))
                    }
                } else {
                    let totalCount = Int64(pow(10.0, Double(remainingDigitsCount)))
                    let countToGenerate = min(totalCount, maxNumbersPerRange)
                    
                    if let baseNumber = Int64(fullPrefix) {
                        let multiplier = Int64(pow(10.0, Double(remainingDigitsCount)))
                        let startNumber = baseNumber * multiplier
                        let endNumber = startNumber + (countToGenerate - 1)
                        rawRanges.append(PhoneNumberRange(start: startNumber, end: endNumber))
                    }
                }
            }
        }
        
        // Sắp xếp và hợp nhất các dải bị chồng lấn
        return mergeRanges(rawRanges.sorted())
    }
    
    /// Hợp nhất các dải số liên tiếp hoặc chồng lấn để đảm bảo tăng dần và không trùng lặp
    private static func mergeRanges(_ sortedRanges: [PhoneNumberRange]) -> [PhoneNumberRange] {
        guard !sortedRanges.isEmpty else { return [] }
        
        var merged: [PhoneNumberRange] = []
        var current = sortedRanges[0]
        
        for i in 1..<sortedRanges.count {
            let next = sortedRanges[i]
            if next.start <= current.end + 1 {
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
