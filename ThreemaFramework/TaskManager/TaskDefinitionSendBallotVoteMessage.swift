import Foundation

@objc final class TaskDefinitionSendBallotVoteMessage: TaskDefinitionSendMessage {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSendBallotVoteMessage(
            taskContext: taskContext,
            taskDefinition: self,
            backgroundFrameworkInjector: frameworkInjector
        )
    }

    override func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol {
        create(
            frameworkInjector: frameworkInjector,
            taskContext: TaskContext(
                logReflectMessageToMediator: .reflectOutgoingMessageToMediator,
                logReceiveMessageAckFromMediator: .receiveOutgoingMessageAckFromMediator,
                logSendMessageToChat: .sendOutgoingMessageToChat,
                logReceiveMessageAckFromChat: .receiveOutgoingMessageAckFromChat
            )
        )
    }
    
    override var description: String {
        "<\(Swift.type(of: self)) type: Ballot id: \(ballotID.hexString)>"
    }
    
    let ballotID: Data
    
    private enum CodingKeys: String, CodingKey {
        case ballotID
    }
    
    @objc init(ballotID: Data, receiverIdentity: String?, group: Group?, sendContactProfilePicture: Bool) {
        self.ballotID = ballotID
        super.init(
            receiverIdentity: receiverIdentity,
            group: group,
            sendContactProfilePicture: sendContactProfilePicture
        )
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.ballotID = try container.decode(Data.self, forKey: .ballotID)

        let superdecoder = try container.superDecoder()
        try super.init(from: superdecoder)
    }
    
    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ballotID, forKey: .ballotID)

        let superencoder = container.superEncoder()
        try super.encode(to: superencoder)
    }
}
