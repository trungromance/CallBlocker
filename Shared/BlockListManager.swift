import Foundation
import CallKit

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

public class BlockListManager {
    public static let shared = BlockListManager()
    
    // App Group identifier (Cấu hình chung giữa Main App và Extension)
    public static let appGroupID = "group.com.altserver.callblocker"
    private let userDefaultsKey = "saved_block_rules"
    private let isMasterEnabledKey = "is_call_blocker_master_enabled"
    
    private var sharedDefaults: UserDefaults {
        return UserDefaults(suiteName: BlockListManager.appGroupID) ?? UserDefaults.standard
    }
    
    private init() {}
    
    public var isMasterEnabled: Bool {
        get {
            // Mặc định là bật (true) nếu chưa lưu
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
        guard let data = sharedDefaults.data(forKey: userDefaultsKey),
              let rules = try? JSONDecoder().decode([BlockPrefixRule].self, from: data) else {
            // Giá trị mặc định ban đầu: 059*
            return [
                BlockPrefixRule(prefix: "059", totalDigits: 10, countryCode: "84", isEnabled: true, note: "Chặn dải đầu số 059*")
            ]
        }
        return rules
    }
    
    public func saveRules(_ rules: [BlockPrefixRule]) {
        if let data = try? JSONEncoder().encode(rules) {
            sharedDefaults.set(data, forKey: userDefaultsKey)
        }
    }
    
    public func addRule(prefix: String, totalDigits: Int = 10, countryCode: String = "84", note: String = "") {
        var rules = getRules()
        // Chuẩn hoá prefix: loại bỏ dấu *, khoảng trắng
        let cleanPrefix = prefix.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrefix.isEmpty else { return }
        
        // Tránh trùng lặp
        if !rules.contains(where: { $0.prefix == cleanPrefix && $0.countryCode == countryCode && $0.totalDigits == totalDigits }) {
            rules.append(BlockPrefixRule(prefix: cleanPrefix, totalDigits: totalDigits, countryCode: countryCode, isEnabled: true, note: note))
            saveRules(rules)
        }
    }
    
    public func removeRule(at offsets: IndexSet) {
        var rules = getRules()
        rules.remove(atOffsets: offsets)
        saveRules(rules)
    }
    
    public func toggleRule(id: UUID) {
        var rules = getRules()
        if let index = rules.firstIndex(where: { $0.id == id }) {
            rules[index].isEnabled.toggle()
            saveRules(rules)
        }
    }
    
    // Yêu cầu iOS reload lại extension để áp dụng danh sách mới
    public func reloadExtension(completion: @escaping (Error?) -> Void) {
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: "com.altserver.callblocker.extension") { error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
    }
    
    // Kiểm tra trạng thái cấp quyền của Extension trong Cài đặt iPhone
    public func checkExtensionStatus(completion: @escaping (CXCallDirectoryManager.EnabledStatus, Error?) -> Void) {
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: "com.altserver.callblocker.extension") { status, error in
            DispatchQueue.main.async {
                completion(status, error)
            }
        }
    }
}
