import libthreemaSwift

extension LibthreemaReadReceiptPolicy {
    init?(_ readReceipt: ContactEntity.ReadReceipt) {
        let rawValue: Int32 =
            switch readReceipt {
            case .doNotSend: LibthreemaReadReceiptPolicy.dontSendReadReceipt.rawValue
            case .send: LibthreemaReadReceiptPolicy.sendReadReceipt.rawValue
            case .default: -1
            }
        self.init(rawValue: rawValue)
    }
}
