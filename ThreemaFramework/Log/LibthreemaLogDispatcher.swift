import CocoaLumberjackSwift
import libthreemaSwift

class LibthreemaLogDispatcher: LogDispatcher {
    func log(level: LogLevel, record: String) throws {
        switch level {
        case .trace:
            DDLogVerbose("[libthreema] \(record)")
        case .debug:
            DDLogDebug("[libthreema] \(record)")
        case .info:
            // Info should also be logged in release builds. Thus we map it to notice
            DDLogNotice("[libthreema] \(record)")
        case .warn:
            DDLogWarn("[libthreema] \(record)")
        case .error:
            DDLogError("[libthreema] \(record)")
        }
    }
}
