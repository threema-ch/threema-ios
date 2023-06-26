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
import Foundation

/// Keeps track of CallIDs for calls that happened in the past two weeks to allow distinguishing between late arriving
/// hangup messages and hangup messages for actually missed calls.
/// Actually missed calls can be identified by never having received or sent a call offer message for the CallID
/// associated with the call.
@objc public class CallHistoryManager: NSObject {
    private let identity: String
    private let businessInjector: BusinessInjectorProtocol
    
    public init(identity: String, businessInjector: BusinessInjectorProtocol) {
        self.identity = identity
        self.businessInjector = businessInjector
    }
    
    public func store(callID: UInt32, date: Date) async {
        await CallHistoryManager.removeCallsOlderThanChatServerTimeout(businessInjector: businessInjector)
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            businessInjector.entityManager.performBlock {
                guard let call = self.businessInjector.entityManager.entityCreator.callEntity() else {
                    fatalError()
                }
                call.callID = NSNumber(value: callID)
                call.date = date
                call.contact = self.businessInjector.entityManager.entityFetcher.contact(for: self.identity)
                
                continuation.resume()
            }
        }
    }
    
    public func isMissedCall(from identity: String, callID: UInt32) async -> Bool {
        await CallHistoryManager.removeCallsOlderThanChatServerTimeout(businessInjector: businessInjector)
        
        let callList = await fetchCallList(identity: identity, callID: callID)
        return callList.isEmpty
    }
    
    private func fetchCallList(identity: String, callID: UInt32) async -> [CallEntity] {
        await withCheckedContinuation { continuation in
            businessInjector.entityManager.performBlock {
                guard let calls = self.businessInjector.entityManager.entityFetcher
                    .allCalls(with: identity, callID: callID) as? [CallEntity] else {
                    DDLogError("Could not fetch calls.")
                    continuation.resume(returning: [CallEntity]())
                    return
                }
                return continuation.resume(returning: calls)
            }
        }
    }
}

extension CallHistoryManager {
    @objc public static func removeCallsOlderThanChatServerTimeout() {
        removeCallsOlderThanChatServerTimeout(businessInjector: BusinessInjector())
    }
    
    public static func removeCallsOlderThanChatServerTimeout(businessInjector: BusinessInjectorProtocol) {
        businessInjector.backgroundEntityManager.performAsyncBlockAndSafe {
            businessInjector.backgroundEntityManager.entityDestroyer.deleteMissedCallsCacheOlderThanTwoWeeks()
        }
    }
    
    public static func removeCallsOlderThanChatServerTimeout(businessInjector: BusinessInjectorProtocol) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            businessInjector.entityManager.performAsyncBlockAndSafe {
                businessInjector.entityManager.entityDestroyer.deleteMissedCallsCacheOlderThanTwoWeeks()
                continuation.resume()
            }
        }
    }
}
