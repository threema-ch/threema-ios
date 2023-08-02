//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

protocol TaskContextProtocol {
    var logReflectMessageToMediator: LoggingTag { get }
    var logReceiveMessageAckFromMediator: LoggingTag { get }
    var logSendMessageToChat: LoggingTag { get }
    var logReceiveMessageAckFromChat: LoggingTag { get }
}

final class TaskContext: TaskContextProtocol {
    var logReflectMessageToMediator: LoggingTag
    var logReceiveMessageAckFromMediator: LoggingTag
    var logSendMessageToChat: LoggingTag
    var logReceiveMessageAckFromChat: LoggingTag

    required init(
        logReflectMessageToMediator: LoggingTag,
        logReceiveMessageAckFromMediator: LoggingTag,
        logSendMessageToChat: LoggingTag,
        logReceiveMessageAckFromChat: LoggingTag
    ) {
        self.logReflectMessageToMediator = logReflectMessageToMediator
        self.logReceiveMessageAckFromMediator = logReceiveMessageAckFromMediator
        self.logSendMessageToChat = logSendMessageToChat
        self.logReceiveMessageAckFromChat = logReceiveMessageAckFromChat
    }

    required convenience init() {
        self.init(
            logReflectMessageToMediator: .none,
            logReceiveMessageAckFromMediator: .none,
            logSendMessageToChat: .none,
            logReceiveMessageAckFromChat: .none
        )
    }
}
