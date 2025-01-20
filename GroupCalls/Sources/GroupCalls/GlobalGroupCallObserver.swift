//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
