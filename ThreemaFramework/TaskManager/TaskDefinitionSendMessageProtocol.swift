import Foundation

protocol TaskDefinitionSendMessageProtocol {
    var messageAlreadySentToQueue: DispatchQueue { get }
    var messageAlreadySentTo: TaskReceiverNonce { get set }
}
