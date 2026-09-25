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

public struct BlockLogItem: Codable, Identifiable {
    public var id: UUID = UUID()
    public var title: String
    public var detail: String
    public var date: Date
    public var isSuccess: Bool
    
    public init(id: UUID = UUID(), title: String, detail: String, date: Date = Date(), isSuccess: Bool = true) {
        self.id = id
        self.title = title
        self.detail = detail
        self.date = date
        self.isSuccess = isSuccess
    }
}

public class BlockListManager {
    public static let shared = BlockListManager()
    
    // App Group identifier (Cấu hình chung giữa Main App và Extension)
    public static let appGroupID = "group.com.luongtrung.callblocker"
    private let userDefaultsKey = "saved_block_rules"
    private let logsDefaultsKey = "saved_block_logs"
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
            addLog(
                title: newValue ? "Bật hệ thống chặn" : "Tắt hệ thống chặn",
                detail: newValue ? "Đã kích hoạt chế độ chặn toàn cục" : "Đã tạm dừng chặn toàn bộ cuộc gọi",
                isSuccess: true
            )
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
            addLog(
                title: "Thêm đầu số chặn mới",
                detail: "Đầu số: \(cleanPrefix)* (\(note.isEmpty ? "Không có ghi chú" : note))",
                isSuccess: true
            )
        }
    }
    
    public func removeRule(at offsets: IndexSet) {
        var rules = getRules()
        for index in offsets.sorted(by: >) {
            if index < rules.count {
                let removed = rules[index]
                rules.remove(at: index)
                addLog(
                    title: "Xóa đầu số chặn",
                    detail: "Đã xóa dải số \(removed.prefix)* khỏi danh sách",
                    isSuccess: true
                )
            }
        }
        saveRules(rules)
    }
    
    public func toggleRule(id: UUID) {
        var rules = getRules()
        if let index = rules.firstIndex(where: { $0.id == id }) {
            rules[index].isEnabled.toggle()
            let state = rules[index].isEnabled ? "Bật" : "Tắt"
            addLog(
                title: "\(state) chặn dải số",
                detail: "Dải số \(rules[index].prefix)* hiện đang \(state)",
                isSuccess: true
            )
            saveRules(rules)
        }
    }
    
    // MARK: - Quản lý Lịch sử (Logs)
    public func getLogs() -> [BlockLogItem] {
        guard let data = sharedDefaults.data(forKey: logsDefaultsKey),
              let logs = try? JSONDecoder().decode([BlockLogItem].self, from: data) else {
            return [
                BlockLogItem(title: "Khởi tạo hệ thống", detail: "Đã thiết lập dải số mặc định 059*", date: Date())
            ]
        }
        return logs
    }
    
    public func addLog(title: String, detail: String, isSuccess: Bool = true) {
        var logs = getLogs()
        logs.insert(BlockLogItem(title: title, detail: detail, date: Date(), isSuccess: isSuccess), at: 0)
        if logs.count > 50 {
            logs = Array(logs.prefix(50))
        }
        if let data = try? JSONEncoder().encode(logs) {
            sharedDefaults.set(data, forKey: logsDefaultsKey)
        }
    }
    
    public func clearLogs() {
        sharedDefaults.removeObject(forKey: logsDefaultsKey)
    }
    
    // MARK: - Kiểm tra số điện thoại có bị chặn hay không
    public func checkNumberBlocked(input: String) -> (isBlocked: Bool, matchedRule: BlockPrefixRule?) {
        guard isMasterEnabled else { return (false, nil) }
        
        var cleanInput = input.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanInput.hasPrefix("+84") {
            cleanInput = "0" + cleanInput.dropFirst(3)
        }
        
        let rules = getRules()
        for rule in rules where rule.isEnabled {
            var rulePrefix = rule.prefix
            if !rulePrefix.hasPrefix("0") {
                rulePrefix = "0" + rulePrefix
            }
            if cleanInput.hasPrefix(rulePrefix) {
                return (true, rule)
            }
        }
        return (false, nil)
    }
    
    // MARK: - Tổng số lượng số điện thoại được bảo vệ
    public func getTotalProtectedNumbersCount() -> Int {
        guard isMasterEnabled else { return 0 }
        let ranges = PhoneNumberGenerator.generateRanges(from: getRules())
        var count: Int64 = 0
        for r in ranges {
            count += (r.end - r.start + 1)
        }
        return Int(count)
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
                if error == nil {
                    self.addLog(
                        title: "Đồng bộ thành công vào iOS",
                        detail: "Đã nạp \(self.getTotalProtectedNumbersCount()) số điện thoại vào hệ điều hành",
                        isSuccess: true
                    )
                }
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
