//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

extension Publisher {
    func debounceSnapshots<S: Scheduler>(scheduler: S) -> Publishers.SnapshotDebouncer<Self, S> {
        .init(upstream: self, scheduler: scheduler)
    }
}

extension Publishers {
    struct SnapshotDebouncer<Upstream: Publisher, Context: Scheduler>: Publisher
        where Upstream.Output == ChatViewSnapshotProvider.SnapshotInfo {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The scheduler on which to publish elements.
        public let scheduler: Context
        
        public init(upstream: Upstream, scheduler: Context) {
            self.upstream = upstream
            self.scheduler = scheduler
        }
        
        public func receive<S: Subscriber>(subscriber: S) where Upstream.Failure == S.Failure,
            Upstream.Output == S.Input {
            upstream.subscribe(SnapshotDebounceSub(pub: self, sub: subscriber))
        }
    }
}

extension Publishers.SnapshotDebouncer {
    private final class SnapshotDebounceSub<S>: Subscription,
        Subscriber,
        CustomStringConvertible,
        CustomDebugStringConvertible
        where
        S: Subscriber, S.Input == ChatViewSnapshotProvider.SnapshotInfo, S.Failure == Failure {
        
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        typealias Pub = Publishers.SnapshotDebouncer<Upstream, Context>
        typealias Sub = S
        
        let lock = NSRecursiveLock()
        let scheduler: Context
        let subscriber: Sub
        
        var state = CombineXRelayState.waiting
        var demand: Subscribers.Demand = .none
        var latest: Input?
        
        init(pub: Pub, sub: Sub) {
            self.scheduler = pub.scheduler
            self.subscriber = sub
            
            sendValuesIfDemanded()
        }
        
        func request(_ demand: Subscribers.Demand) {
            DDLogVerbose("CombineSnapshot \(#function) has demand \(demand)")
            lock.lock()
            
            guard let subscription = state.subscription else {
                lock.unlock()
                return
            }
            self.demand += demand
            
            subscription.request(.unlimited)
            
            lock.unlock()
            
            sendValuesIfDemanded()
        }
        
        func cancel() {
            lock.withLockGet(state.complete())?.cancel()
            latest = nil
        }
        
        func receive(subscription: Subscription) {
            guard lock.withLockGet(state.relay(subscription)) else {
                DDLogError("Cancelling subscription")
                subscription.cancel()
                return
            }
            
            subscriber.receive(subscription: self)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            
            guard state.isRelaying else {
                return .none
            }
            if let latest = latest {
                DDLogVerbose("CombineSnapshot \(#function) Batch Snapshots")
                self.latest = ChatViewSnapshotProvider.batchSnapshotsTogether(latest, input)
            }
            else {
                latest = input
            }
            
            lock.unlock()
            
            sendValuesIfDemanded()
            
            return .unlimited
        }
        
        private func sendValuesIfDemanded() {
            scheduler.schedule { [self] in
                DDLogVerbose("CombineSnapshot \(#function) demand \(self.demand)")
                
                lock.lock()
                guard state.isRelaying else {
                    lock.unlock()
                    return
                }
                guard demand > 0 else {
                    lock.unlock()
                    return
                }
                if let latest = latest {
                    self.latest = nil
                    demand -= 1
                    lock.unlock()
                    let additionalDemand = subscriber.receive(latest)
                    
                    lock.withLock {
                        self.demand += additionalDemand
                    }
                }
                else {
                    lock.unlock()
                }
            }
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            guard let subscription = lock.withLockGet(state.complete()) else {
                return
            }
            subscription.cancel()
            latest = nil
            
            subscriber.receive(completion: completion)
        }
        
        var description: String {
            "DebounceSnapshots"
        }
        
        var debugDescription: String {
            "DebounceSnapshots"
        }
    }
}
