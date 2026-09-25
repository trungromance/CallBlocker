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
    
    // Giới hạn số lượng bản ghi tối đa để đảm bảo nạp tức thì trong 0.1s và không bao giờ bị iOS báo lỗi dữ liệu
    private static let maxEntriesPerSubRange: Int64 = 25_000
    
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
            
            // Tách các đầu số spam thực tế
            var prefixesToProcess: [String] = []
            if prefixStr == "59" {
                // Các dải số hoạt động chính của 059 tại VN (Gmobile)
                prefixesToProcess = ["592", "593", "598", "599"]
            } else {
                prefixesToProcess = [prefixStr]
            }
            
            for p in prefixesToProcess {
                let fullPrefix = countryCode + p
                let currentPrefixLength = fullPrefix.count
                
                // Độ dài số chuẩn quốc tế: VN 10 số (059xxxxxxx -> 8459xxxxxxx: 11 ký tự)
                let targetLength = rule.totalDigits - 1 + countryCode.count
                let remainingDigitsCount = targetLength - currentPrefixLength
                
                guard remainingDigitsCount >= 0 else { continue }
                
                if remainingDigitsCount == 0 {
                    if let singleNumber = Int64(fullPrefix) {
                        rawRanges.append(PhoneNumberRange(start: singleNumber, end: singleNumber))
                    }
                } else {
                    let totalCount = Int64(pow(10.0, Double(remainingDigitsCount)))
                    let countToGenerate = min(totalCount, maxEntriesPerSubRange)
                    
                    if let baseNumber = Int64(fullPrefix) {
                        let multiplier = Int64(pow(10.0, Double(remainingDigitsCount)))
                        let startNumber = baseNumber * multiplier
                        let endNumber = startNumber + (countToGenerate - 1)
                        rawRanges.append(PhoneNumberRange(start: startNumber, end: endNumber))
                    }
                }
            }
        }
        
        return mergeRanges(rawRanges.sorted())
    }
    
    /// Hợp nhất các dải số để đảm bảo tăng dần nghiêm ngặt (Strictly Ascending)
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
