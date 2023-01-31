//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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
import XCTest
@testable import ThreemaFramework

class ValidationLoggerMock: NSObject, ValidationLoggerProtocol {
    func logBoxedMessage(_ boxedMessage: BoxedMessage!, isIncoming incoming: Bool, description: String!) { }
    
    func logSimpleMessage(_ message: AbstractMessage!, isIncoming incoming: Bool, description: String!) { }
    
    func logString(_ logMessage: String!) { }
}

// class ValidationLoggerMock: ValidationLogger {
//
//    var expectedLogMessage: String?
//    var logMessage: String?
//
//    func expected(logMessage: String?) {
//        self.expectedLogMessage = logMessage
//    }
//
//    func verify() {
//        XCTAssertEqual(self.expectedLogMessage, self.logMessage)
//    }
//
//    override class func shared() -> ValidationLogger! {
//        return ValidationLoggerMock()
//    }
//
//    override func logString(_ logMessage: String?) {
//        self.logMessage = logMessage
//    }
// }
