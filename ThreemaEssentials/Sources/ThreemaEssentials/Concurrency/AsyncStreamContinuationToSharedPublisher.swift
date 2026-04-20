import CocoaLumberjackSwift
import Combine
import Foundation

/// Sends sendable values from one async stream continuation to many Combine subscribers
///
/// Ideally we'd be able to do this directly in the AsyncStream but at the moment there is no easier
/// way for sharing an "async stream" to many subscribers.
public final class AsyncStreamContinuationToSharedPublisher<Output: Sendable>: Sendable {
    public let publisher = SharedPublisher<Output>()
    
    private let stateQueue: AsyncStream<Output>
    public let stateContinuation: AsyncStream<Output>.Continuation
    
    // MARK: - Private properties
    
    private let queue = DispatchQueue(label: "ch.threema.AsyncStreamContinuationToSharedPublisher")
    
    private var lastItem: Output?

    // MARK: - Lifecycle
    
    public init() {
        (self.stateQueue, self.stateContinuation) = AsyncStream<Output>.makeStream()
        
        Task {
            await subscribeAndPublish()
        }
    }
    
    // MARK: - Helper Functions
    
    private func subscribeAndPublish() async {
        for await item in stateQueue {
            queue.async { [weak self] in
                self?.publisher.source.send(item)
                self?.lastItem = item
            }
        }
    }
    
    public func getCurrentItem() async -> Output? {
        await withCheckedContinuation { cont in
            queue.async {
                cont.resume(returning: self.lastItem)
            }
        }
    }
}
