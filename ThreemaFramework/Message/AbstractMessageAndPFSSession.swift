//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

import Foundation

/// A helper object to facilitate communication / passing Swift objects between TaskExecutionReceiveMessage and MessageProcessor
@objc class AbstractMessageAndPFSSession: NSObject {
    @objc let session: AnyObject? // Must be a DHSession
    @objc let message: AbstractMessage?
    
    @objc init(session: AnyObject? = nil, message: AbstractMessage? = nil) {
        assert(session == nil || session!.isKind(of: DHSession.self))
        assert(!(session != nil && message == nil))
        
        self.session = session
        self.message = message
    }
}
