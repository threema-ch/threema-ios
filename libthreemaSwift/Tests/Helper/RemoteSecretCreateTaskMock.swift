import libthreemaSwift
import ThreemaEssentials

public final class RemoteSecretCreateTaskMock: RemoteSecretCreateTaskProtocol {
    
    public enum PollResponse {
        case instruction(HttpsRequest)
        case done(RemoteSecretCreateResult)
        case error(RemoteSecretSetupError)
        
        func map() throws -> RemoteSecretCreateLoop {
            switch self {
            case let .instruction(request):
                return .instruction(request)
            case let .done(result):
                return .done(result)
            case let .error(error):
                throw error
            }
        }
    }
    
    public let pollResponses: Atomic<[PollResponse]> = Atomic(wrappedValue: [])
    public let responses: Atomic<[HttpsResult]> = Atomic(wrappedValue: [])
    
    public init(pollResponses: [PollResponse]) {
        self.pollResponses.wrappedValue = pollResponses
    }
    
    public func poll() throws -> RemoteSecretCreateLoop {
        try pollResponses.wrappedValue.removeFirst().map()
    }
    
    public func response(response: HttpsResult) throws {
        responses.wrappedValue.append(response)
    }
}
