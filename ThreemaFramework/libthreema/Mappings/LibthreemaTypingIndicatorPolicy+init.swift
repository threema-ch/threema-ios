import libthreemaSwift

extension LibthreemaTypingIndicatorPolicy {
    init?(_ typingIndicator: ContactEntity.TypingIndicator) {
        let rawValue: Int32 =
            switch typingIndicator {
            case .doNotSend: LibthreemaTypingIndicatorPolicy.dontSendTypingIndicator.rawValue
            case .send: LibthreemaTypingIndicatorPolicy.sendTypingIndicator.rawValue
            case .default: -1
            }
        self.init(rawValue: rawValue)
    }
}
