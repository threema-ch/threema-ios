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

// MARK: - Protocol and Extension

public protocol GroupCallErrorProtocol {
    var alertTitleKey: String { get }
    var alertMessageKey: String { get }
    var isFatal: Bool { get }
}

extension GroupCallErrorProtocol {
    public var alertTitleKey: String {
        "group_call_error_generic_title"
    }

    public var alertMessageKey: String {
        "group_call_error_generic_message"
    }
    
    public var isFatal: Bool {
        false
    }
}

// MARK: - Errors

public enum GroupCallError: Error, GroupCallErrorProtocol {

    case creationError
    case groupNotFound
    
    case keyRatchetError
    case frameCryptoFailure
    
    case localProtocolViolation
    
    case badMessage
    case firstMessageNotReceived
    case tokenFailure
    
    case serializationFailure
    case encryptionFailure
    case decryptionFailure
}

public enum GroupCallParticipantError: Error, GroupCallErrorProtocol {
    case encryptionFailure
    case badParticipantState
}

public enum GroupCallViewModelError: Error, GroupCallErrorProtocol {
    case toggleOwnVideoFailed
    case toggleOwnAudioFailed
}
