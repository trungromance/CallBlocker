import Foundation
import CallKit
#if canImport(SwiftUI)
import SwiftUI
#endif

public struct BlockPrefixRule: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var prefix: String
    public var totalDigits: Int // e.g. 10 digits for standard VN mobile numbers (059xxxxxxx)
    public var countryCode: String // e.g. "84"
    public var isEnabled: Bool
    public var note: String
    
    public init(id: UUID = UUID(), prefix: String, totalDigits: Int = 10, countryCode: String = "84", isEnabled: Bool = true, note: String = "") {
        self.id = id
        self.prefix = prefix
        self.totalDigits = totalDigits
        self.countryCode = countryCode
        self.isEnabled = isEnabled
        self.note = note
    }
}

public struct BlockedCallRecord: Codable, Identifiable {
    public var id: UUID = UUID()
    public var phoneNumber: String
    public var prefix: String
    public var timestamp: Date
    public var note: String
    
    public init(id: UUID = UUID(), phoneNumber: String, prefix: String, timestamp: Date = Date(), note: String = "Tự động chặn") {
        self.id = id
        self.phoneNumber = phoneNumber
        self.prefix = prefix
        self.timestamp = timestamp
        self.note = note
    }
}

public class BlockListManager {
    public static let shared = BlockListManager()
    
    // App Group identifier (Cấu hình chung giữa Main App và Extension)
    public static let appGroupID = "group.com.luongtrung.callblocker"
    private let userDefaultsKey = "saved_block_rules"
    private let blockedCallsKey = "saved_blocked_calls_history"
    private let isMasterEnabledKey = "is_call_blocker_master_enabled"
    
    private var sharedDefaults: UserDefaults {
        return UserDefaults(suiteName: BlockListManager.appGroupID) ?? UserDefaults.standard
    }
    
    // Đường dẫn file lưu trữ chia sẻ dự phòng
    private var sharedFileURL: URL? {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: BlockListManager.appGroupID) {
            return containerURL.appendingPathComponent("call_blocker_rules.json")
        }
        return nil
    }
    
    private init() {}
    
    public var isMasterEnabled: Bool {
        get {
            if sharedDefaults.object(forKey: isMasterEnabledKey) == nil {
                return true
            }
            return sharedDefaults.bool(forKey: isMasterEnabledKey)
        }
        set {
            sharedDefaults.set(newValue, forKey: isMasterEnabledKey)
        }
    }
    
    public func getRules() -> [BlockPrefixRule] {
        if let data = sharedDefaults.data(forKey: userDefaultsKey),
           let rules = try? JSONDecoder().decode([BlockPrefixRule].self, from: data) {
            return rules
        }
        
        if let fileURL = sharedFileURL,
           let data = try? Data(contentsOf: fileURL),
           let rules = try? JSONDecoder().decode([BlockPrefixRule].self, from: data) {
            return rules
        }
        
        return [
            BlockPrefixRule(prefix: "059", totalDigits: 10, countryCode: "84", isEnabled: true, note: "Chặn dải đầu số 059*")
        ]
    }
    
    public func saveRules(_ rules: [BlockPrefixRule]) {
        if let data = try? JSONEncoder().encode(rules) {
            sharedDefaults.set(data, forKey: userDefaultsKey)
            if let fileURL = sharedFileURL {
                try? data.write(to: fileURL)
            }
        }
    }
    
    public func addRule(prefix: String, totalDigits: Int = 10, countryCode: String = "84", note: String = "") {
        var rules = getRules()
        let cleanPrefix = prefix.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrefix.isEmpty else { return }
        
        if !rules.contains(where: { $0.prefix == cleanPrefix && $0.countryCode == countryCode && $0.totalDigits == totalDigits }) {
            let newRule = BlockPrefixRule(prefix: cleanPrefix, totalDigits: totalDigits, countryCode: countryCode, isEnabled: true, note: note)
            rules.append(newRule)
            saveRules(rules)
        }
    }
    
    public func removeRule(at offsets: IndexSet) {
        var rules = getRules()
        for index in offsets.sorted(by: >) {
            if index < rules.count {
                rules.remove(at: index)
            }
        }
        saveRules(rules)
    }
    
    public func toggleRule(id: UUID) {
        var rules = getRules()
        if let index = rules.firstIndex(where: { $0.id == id }) {
            rules[index].isEnabled.toggle()
            saveRules(rules)
        }
    }
    
    // MARK: - Quản lý Lịch sử cuộc gọi bị chặn 30 ngày (100% dữ liệu thực tế)
    public func getBlockedCallsHistory() -> [BlockedCallRecord] {
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
        
        guard let data = sharedDefaults.data(forKey: blockedCallsKey),
              let records = try? JSONDecoder().decode([BlockedCallRecord].self, from: data) else {
            return []
        }
        
        // Lọc nghiêm ngặt trong 30 ngày gần nhất
        let filtered = records.filter { $0.timestamp >= thirtyDaysAgo }
        return filtered.sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    public func saveBlockedCallsHistory(_ records: [BlockedCallRecord]) {
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
        let filtered = records.filter { $0.timestamp >= thirtyDaysAgo }
        if let data = try? JSONEncoder().encode(filtered) {
            sharedDefaults.set(data, forKey: blockedCallsKey)
        }
    }
    
    public func recordBlockedCall(phoneNumber: String, prefix: String, note: String = "Tự động chặn") {
        var records = getBlockedCallsHistory()
        records.insert(BlockedCallRecord(phoneNumber: phoneNumber, prefix: prefix, timestamp: Date(), note: note), at: 0)
        saveBlockedCallsHistory(records)
    }
    
    public func clearBlockedCallsHistory() {
        sharedDefaults.removeObject(forKey: blockedCallsKey)
    }
    
    private var extensionIdentifier: String {
        let baseID = Bundle.main.bundleIdentifier ?? "com.luongtrung.callblocker"
        if baseID.hasSuffix(".extension") {
            return baseID
        }
        return "\(baseID).extension"
    }
    
    public func reloadExtension(completion: @escaping (Error?) -> Void) {
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionIdentifier) { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    public func checkExtensionStatus(completion: @escaping (CXCallDirectoryManager.EnabledStatus, Error?) -> Void) {
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: extensionIdentifier) { status, error in
            DispatchQueue.main.async {
                completion(status, error)
            }
        }
    }
}
