import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        // Nếu người dùng đã từng import và đây là lần import lại đầy đủ
        if context.isIncremental {
            addAllBlockingPhoneNumbers(to: context)
        } else {
            addAllBlockingPhoneNumbers(to: context)
        }

        context.completeRequest()
    }

    private func addAllBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        let manager = BlockListManager.shared
        
        // Kiểm tra nút Bật/Tắt tổng thể của App
        guard manager.isMasterEnabled else {
            // Nếu tắt, không nạp số nào vào danh sách chặn
            return
        }
        
        let rules = manager.getRules()
        let ranges = PhoneNumberGenerator.generateRanges(from: rules)
        
        // CallKit yêu cầu thêm số theo thứ tự số nguyên TĂNG DẦN tuyệt đối
        for range in ranges {
            var currentNumber = range.start
            while currentNumber <= range.end {
                context.addBlockingEntry(withNextSequentialPhoneNumber: CXCallDirectoryPhoneNumber(currentNumber))
                currentNumber += 1
            }
        }
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        // Xử lý khi nạp dữ liệu thất bại
        print("CallDirectoryHandler error: \(error.localizedDescription)")
    }
}
