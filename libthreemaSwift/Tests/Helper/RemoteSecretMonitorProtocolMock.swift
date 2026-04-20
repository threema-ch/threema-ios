import Foundation
import libthreemaSwift
import ThreemaEssentials

public final class RemoteSecretMonitorProtocolMock: RemoteSecretMonitorProtocolProtocol {
    
    public enum PollResponse {
        case request(HttpsRequest)
        case schedule(timeout: TimeInterval, remoteSecret: Data?)
        case error(RemoteSecretMonitorError)
        
        func map() throws -> RemoteSecretMonitorInstruction {
            switch self {
            case let .request(request):
                return .request(request)
            case let .schedule(timeout: timeout, remoteSecret: remoteSecret):
                return .schedule(timeout: timeout, remoteSecret: remoteSecret)
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
    
    public func poll() throws -> RemoteSecretMonitorInstruction {
        try pollResponses.wrappedValue.removeFirst().map()
    }
    
    public func response(response: HttpsResult) throws {
        responses.wrappedValue.append(response)
    }
}
