//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CocoaLumberjackSwift
import Combine
import Foundation
import ThreemaProtocols

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
