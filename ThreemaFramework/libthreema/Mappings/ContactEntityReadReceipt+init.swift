import libthreemaSwift

extension ContactEntity.ReadReceipt {
    init?(_ libthreemaReadReceiptPolicy: LibthreemaReadReceiptPolicy?) {
        guard let libthreemaReadReceiptPolicy else {
            self.init(rawValue: ContactEntity.ReadReceipt.default.rawValue)
            return
        }

        let readReceipt: ContactEntity.ReadReceipt =
            switch libthreemaReadReceiptPolicy {
            case .dontSendReadReceipt: .doNotSend
            case .sendReadReceipt: .send
            }
        self.init(rawValue: readReceipt.rawValue)
    }
}
