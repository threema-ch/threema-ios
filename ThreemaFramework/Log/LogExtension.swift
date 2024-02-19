//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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
import CocoaLumberjackSwiftSupport
import Foundation

/// Tagging convention of Log Entry/Message:
///     - One tag: "[t-tag-1] Message of log entry..."
///     - Multible tags: "[t-tag-1,t-tag-2,...] Message of log entry..."
/// Used Tags:
/// [t-dirty-objects]: Dirty objects in Core Data
/// [t-push-notification]: APNS

/// Note: Add Log level for Swift in Build Settings - Preprocessor Macros for AdHoc and AppStore:
/// DD_LOG_LEVEL=0b0100011 (Error, Warning and Notice)

/// Swift method for logging Notice Log level
@inlinable
public func DDLogNotice(
    _ message: @autoclosure () -> String,
    level: DDLogLevel = DDDefaultLogLevel,
    context: Int = 0,
    file: StaticString = #file,
    function: StaticString = #function,
    line: UInt = #line,
    tag: Any? = nil,
    asynchronous async: Bool = asyncLoggingEnabled,
    ddlog: DDLog = .sharedInstance
) {
    _DDLogMessage(
        message(),
        level: level,
        flag: DDLogFlag(rawValue: DDLogFlag.RawValue(DDLogFlagNotice)),
        context: context,
        file: file,
        function: function,
        line: line,
        tag: tag,
        asynchronous: async,
        ddlog: ddlog
    )
}
