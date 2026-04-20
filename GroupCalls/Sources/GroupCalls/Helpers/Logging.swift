import CocoaLumberjackSwift
import CocoaLumberjackSwiftSupport
import Foundation

///
/// *** Same as in LogExtension.swift in Threema.app ***
///

/// Tagging convention of Log Entry/Message:
///     - One tag: "[t-tag-1] Message of log entry..."
///     - Multiple tags: "[t-tag-1,t-tag-2,...] Message of log entry..."
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
        flag: DDLogFlag(rawValue: DDLogFlag.RawValue(1 << 5)),
        context: context,
        file: file,
        function: function,
        line: line,
        tag: tag,
        asynchronous: async,
        ddlog: ddlog
    )
}
