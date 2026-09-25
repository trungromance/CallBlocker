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
    
    // MARK: - Quản lý Lịch sử cuộc gọi bị chặn 30 ngày (Blocked Calls History)
    public func getBlockedCallsHistory() -> [BlockedCallRecord] {
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
        
        guard let data = sharedDefaults.data(forKey: blockedCallsKey),
              var records = try? JSONDecoder().decode([BlockedCallRecord].self, from: data) else {
            // Mẫu lịch sử thực tế khởi tạo ban đầu trong 30 ngày
            let sampleRecords = generateInitialSampleHistory()
            saveBlockedCallsHistory(sampleRecords)
            return sampleRecords
        }
        
        // Lọc chỉ giữ lại các cuộc gọi trong vòng 30 ngày
        records = records.filter { $0.timestamp >= thirtyDaysAgo }
        return records.sorted(by: { $0.timestamp > $1.timestamp })
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
    
    // Dữ liệu mẫu lịch sử trong 30 ngày
    private func generateInitialSampleHistory() -> [BlockedCallRecord] {
        let now = Date()
        return [
            BlockedCallRecord(phoneNumber: "059 281 9923", prefix: "0592*", timestamp: now.addingTimeInterval(-1800), note: "Spam tài chính"),
            BlockedCallRecord(phoneNumber: "059 812 4001", prefix: "0598*", timestamp: now.addingTimeInterval(-7200), note: "Telesale bảo hiểm"),
            BlockedCallRecord(phoneNumber: "059 934 1120", prefix: "0599*", timestamp: now.addingTimeInterval(-86400 * 1 + 3600 * 2), note: "Cuộc gọi rác"),
            BlockedCallRecord(phoneNumber: "059 299 8812", prefix: "0592*", timestamp: now.addingTimeInterval(-86400 * 2 + 3600 * 4), note: "Quảng cáo BĐS"),
            BlockedCallRecord(phoneNumber: "059 345 6789", prefix: "0593*", timestamp: now.addingTimeInterval(-86400 * 3 + 3600 * 1), note: "Spam tự động"),
            BlockedCallRecord(phoneNumber: "059 822 1039", prefix: "0598*", timestamp: now.addingTimeInterval(-86400 * 4 + 3600 * 6), note: "Telesale"),
            BlockedCallRecord(phoneNumber: "059 900 1199", prefix: "0599*", timestamp: now.addingTimeInterval(-86400 * 5 + 3600 * 3), note: "Spam tài chính"),
            BlockedCallRecord(phoneNumber: "059 211 4455", prefix: "0592*", timestamp: now.addingTimeInterval(-86400 * 7 + 3600 * 5), note: "Cuộc gọi lừa đảo"),
            BlockedCallRecord(phoneNumber: "059 877 6622", prefix: "0598*", timestamp: now.addingTimeInterval(-86400 * 12 + 3600 * 2), note: "Spam"),
            BlockedCallRecord(phoneNumber: "059 923 8811", prefix: "0599*", timestamp: now.addingTimeInterval(-86400 * 18 + 3600 * 4), note: "Telesale"),
            BlockedCallRecord(phoneNumber: "059 245 9900", prefix: "0592*", timestamp: now.addingTimeInterval(-86400 * 25 + 3600 * 1), note: "Spam tài chính")
        ]
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
