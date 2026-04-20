import CocoaLumberjackSwift
import Combine
@preconcurrency import Foundation
import ThreemaEssentials
import ThreemaProtocols

public final class GlobalGroupCallObserver: Sendable {
    
    public let publisher = GlobalGroupCallObserverPublisher()
    
    private let stateQueue: AsyncStream<GroupCallThreemaGroupModel>
    let stateContinuation: AsyncStream<GroupCallThreemaGroupModel>.Continuation
    
    private let queue = DispatchQueue(label: "ch.threema.GlobalGroupCallObserver")
    
    init() {
        (self.stateQueue, self.stateContinuation) = AsyncStream<GroupCallThreemaGroupModel>.makeStream()
        
        Task {
            await subscribeAndPublish()
        }
    }
    
    private func subscribeAndPublish() async {
        for await item in stateQueue {
            queue.async { [weak self] in
                self?.publisher.source.send(item)
            }
        }
    }
}
