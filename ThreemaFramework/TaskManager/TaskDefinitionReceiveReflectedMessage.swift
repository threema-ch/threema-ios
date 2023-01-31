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

class TaskDefinitionReceiveReflectedMessage: TaskDefinition {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionReceiveReflectedMessage(
            taskContext: taskContext,
            taskDefinition: self,
            frameworkInjector: frameworkInjector
        )
    }

    override func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol {
        create(frameworkInjector: frameworkInjector, taskContext: TaskContext())
    }
    
    override var description: String {
        "<\(type(of: self)) \(message?.loggingDescription ?? "unknown message")>"
    }
    
    override private init(isPersistent: Bool) {
        super.init(isPersistent: isPersistent)
    }
    
    convenience init(
        reflectID: Data,
        message: D2d_Envelope,
        mediatorTimestamp: Date,
        receivedAfterInitialQueueSend: Bool,
        maxBytesToDecrypt: Int,
        timeoutDownloadThumbnail: Int
    ) {
        self.init(isPersistent: false)
        self.reflectID = reflectID
        self.message = message
        self.mediatorTimestamp = mediatorTimestamp
        self.receivedAfterInitialQueueSend = receivedAfterInitialQueueSend
        self.maxBytesToDecrypt = Int32(maxBytesToDecrypt)
        self.timeoutDownloadThumbnail = Int32(timeoutDownloadThumbnail)
    }

    var reflectID: Data!
    var message: D2d_Envelope!
    var mediatorTimestamp: Date!
    var receivedAfterInitialQueueSend: Bool!
    var maxBytesToDecrypt: Int32!
    var timeoutDownloadThumbnail: Int32!
    
    required init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
}
