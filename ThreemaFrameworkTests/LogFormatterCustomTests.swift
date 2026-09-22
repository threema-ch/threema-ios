import CocoaLumberjack
import CocoaLumberjackSwift
import XCTest

@testable import ThreemaFramework

/// Regression guard for the custom CocoaLumberjack log format (`LogFormatterCustom`).
///
/// `LogFormatterCustom.formatLogMessage:` builds every log line from this format string:
///
///     "%@ %@[%@:%@] %@:%lu %@ %@"
///      │  │  │  │   │  │   │  └─ message
///      │  │  │  │   │  │   └──── log level tag, e.g. "[Info]"
///      │  │  │  │   │  └──────── source line
///      │  │  │  │   └─────────── source file name
///      │  │  │  └─────────────── thread id
///      │  │  └────────────────── process id
///      │  └───────────────────── process name
///      └──────────────────────── timestamp
///
/// Each test logs a real message, grabs the `DDLogMessage` that CocoaLumberjack builds for it (via
/// `DDLoggerMock`), and asserts the formatter's output equals that exact layout rebuilt from the
/// eight parts. So bumping the CocoaLumberjack dependency and changing the layout – or the log
/// level → tag mapping – fails this test.
final class LogFormatterCustomTests: XCTestCase {

    private let formatter = LogFormatterCustom()
    private var loggerMock: DDLoggerMock!
    private var previousLogLevel: DDLogLevel!

    override func setUpWithError() throws {
        loggerMock = DDLoggerMock()
        DDLog.add(loggerMock)

        // Make sure nothing is filtered out while we drive the logging pipeline.
        previousLogLevel = dynamicLogLevel
        dynamicLogLevel = .all
    }

    override func tearDownWithError() throws {
        DDLog.remove(loggerMock)
        DDLog.flushLog()
        dynamicLogLevel = previousLogLevel
        loggerMock = nil
    }

    // MARK: - Tests

    func testFormatMatchesFormatString() throws {
        let message = "Hello world"
        let logMessage = try captureLogMessage(message) { DDLogInfo("\(message)", level: .all) }

        let formatted = try XCTUnwrap(formatter.format(message: logMessage))

        XCTAssertEqual(formatted, expectedLine(for: logMessage, levelTag: "[Info]"))
    }

    func testEachLogLevelUsesExpectedTag() throws {
        let cases: [(tag: String, log: (String) -> Void)] = [
            ("[Err]", { DDLogError("\($0)", level: .all) }),
            ("[Warn]", { DDLogWarn("\($0)", level: .all) }),
            ("[Info]", { DDLogInfo("\($0)", level: .all) }),
            ("[Debug]", { DDLogDebug("\($0)", level: .all) }),
            ("[Verbose]", { DDLogVerbose("\($0)", level: .all) }),
            ("[Notice]", { DDLogNotice($0, level: .all) }),
        ]

        for testCase in cases {
            let message = "message for \(testCase.tag)"
            let logMessage = try captureLogMessage(message) { testCase.log(message) }

            let formatted = try XCTUnwrap(formatter.format(message: logMessage))

            XCTAssertEqual(formatted, expectedLine(for: logMessage, levelTag: testCase.tag))
        }
    }

    // MARK: - Helpers

    /// Emits a log statement through CocoaLumberjack and returns the `DDLogMessage` it produced.
    private func captureLogMessage(
        _ message: String,
        emittedBy emit: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> DDLogMessage {
        emit()
        DDLog.flushLog()

        return try XCTUnwrap(
            loggerMock.logMessages.last { $0.message == message },
            "Log message was not captured – was it dropped by the log level?",
            file: file,
            line: line
        )
    }

    /// Rebuilds the line `LogFormatterCustom` is expected to produce for `logMessage`, following its
    /// format string "%@ %@[%@:%@] %@:%lu %@ %@".
    private func expectedLine(for logMessage: DDLogMessage, levelTag: String) -> String {
        // Qualified because `@testable import ThreemaFramework` also exposes a `DateFormatter` type.
        let dateFormatter = Foundation.DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZZZZZ"
        let timestamp = dateFormatter.string(from: logMessage.timestamp)

        let processName = ProcessInfo.processInfo.processName
        let processID = "\(getpid())"

        return "\(timestamp) \(processName)[\(processID):\(logMessage.threadID)] "
            + "\(logMessage.fileName):\(logMessage.line) \(levelTag) \(logMessage.message)"
    }
}
