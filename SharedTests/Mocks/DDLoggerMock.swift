import CocoaLumberjackSwift
import Foundation

final class DDLoggerMock: DDAbstractLogger {
    var logMessages = [DDLogMessage]()
    
    func exists(message: String) -> Bool {
        DDLog.flushLog()

        return !logMessages.filter { logMsg in
            logMsg.message == message
        }.isEmpty
    }

    func starts(with message: String) -> Bool {
        DDLog.flushLog()

        return !logMessages.filter { logMsg in
            logMsg.message.starts(with: message)
        }.isEmpty
    }

    override func log(message logMessage: DDLogMessage) {
        logMessages.append(logMessage)
    }
}
