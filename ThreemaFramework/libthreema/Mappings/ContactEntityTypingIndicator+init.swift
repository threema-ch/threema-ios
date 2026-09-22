import libthreemaSwift

extension ContactEntity.TypingIndicator {
    init?(_ libthreemaTypingIndicatorPolicy: LibthreemaTypingIndicatorPolicy?) {
        guard let libthreemaTypingIndicatorPolicy else {
            self.init(rawValue: ContactEntity.TypingIndicator.default.rawValue)
            return
        }

        let typingIndicator: ContactEntity.TypingIndicator =
            switch libthreemaTypingIndicatorPolicy {
            case .dontSendTypingIndicator: .doNotSend
            case .sendTypingIndicator: .send
            }
        self.init(rawValue: typingIndicator.rawValue)
    }
}
