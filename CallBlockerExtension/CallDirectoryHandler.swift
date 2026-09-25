import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        // Nếu đây là lần reload/update (isIncremental), xoá toàn bộ danh sách cũ trước khi nạp lại
        if context.isIncremental {
            context.removeAllBlockingEntries()
        }

        addAllBlockingPhoneNumbers(to: context)
        context.completeRequest()
    }

    private func addAllBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        let manager = BlockListManager.shared
        
        // Kiểm tra nút Bật/Tắt tổng thể của App
        guard manager.isMasterEnabled else {
            return
        }
        
        let rules = manager.getRules()
        let ranges = PhoneNumberGenerator.generateRanges(from: rules)
        
        // Nạp các số điện thoại theo thứ tự TĂNG DẦN tuyệt đối
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
        print("CallDirectoryHandler requestFailed: \(error.localizedDescription)")
    }
}
