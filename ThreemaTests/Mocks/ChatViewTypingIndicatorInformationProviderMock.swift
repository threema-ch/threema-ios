import Foundation

@testable import Threema

final class ChatViewTypingIndicatorInformationProviderMock: ChatViewTypingIndicatorInformationProviderProtocol {
    var currentlyTypingPublisher: Published<Bool>.Publisher { $currentlyTyping }
    
    @Published var currentlyTyping = false
}
