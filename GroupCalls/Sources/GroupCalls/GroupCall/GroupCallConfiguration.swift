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

/// Static Configuration
public enum GroupCallConfiguration {
    enum ProtocolDefines {
        static let protocolVersion: UInt32 = 1
        static let startMessageReceiveTimeout = 60 * 60 * 24 * 14
    }

    enum SubscribeVideo {
        static let fps: UInt32 = 30
        static let width: UInt32 = 720
        static let height: UInt32 = 720
    }
    
    enum SendVideo {
        static let fps: Int32 = 30
        static let width: Int32 = 720
        static let height: Int32 = 720
    }
    
    public enum ActiveCallSwitching {
        public static let delayBeforeReplacingCallInMs = 500
    }
    
    public enum LocalInitialMuteState {
        static let video = OwnMuteState.muted
        static let audio = OwnMuteState.muted
    }
}
