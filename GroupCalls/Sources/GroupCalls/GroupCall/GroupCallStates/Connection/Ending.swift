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
import Foundation

@GlobalGroupCallActor
struct Ending: GroupCallState {

    // MARK: - Private properties
    
    private let groupCallActor: GroupCallActor
    private let groupCallContext: GroupCallContextProtocol?

    // MARK: - Lifecycle

    init(groupCallActor: GroupCallActor, groupCallContext: GroupCallContextProtocol? = nil) {
        // TODO: (IOS-3857) Logging
        DDLogNotice("[GroupCall] Group Call is ending.")
        self.groupCallActor = groupCallActor
        self.groupCallContext = groupCallContext
    }
    
    // MARK: - GroupCallState
    
    // Force continue to ended if this doesn't complete in 10s or something so we don't get
    // stuck in this state...
    func next() async throws -> GroupCallState? {
        
        /// **Leave Call** 3. This is where the cleanup begins
        /// 3.1 We start with the `GroupCallViewModel`, this also dismisses the UI
        await groupCallActor.viewModel.leaveCall()
        
        /// 3.2 We continue with the context
        await groupCallContext?.leave()
                
        return Ended()
    }
}
