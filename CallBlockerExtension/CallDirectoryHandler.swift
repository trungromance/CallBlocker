import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        if context.isIncremental {
            context.removeAllBlockingEntries()
        }

        addAllBlockingPhoneNumbers(to: context)
        context.completeRequest()
    }

    private func addAllBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        let manager = BlockListManager.shared
        
        guard manager.isMasterEnabled else {
            return
        }
        
        let rules = manager.getRules()
        let ranges = PhoneNumberGenerator.generateRanges(from: rules)
        
        for range in ranges {
            var currentNumber = range.start
            while currentNumber <= range.end {
                autoreleasepool {
                    context.addBlockingEntry(withNextSequentialPhoneNumber: CXCallDirectoryPhoneNumber(currentNumber))
                }
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
