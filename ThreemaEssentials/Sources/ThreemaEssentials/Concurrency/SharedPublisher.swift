import CocoaLumberjackSwift
import Combine
import Foundation

public final class SharedPublisher<Output: Any>: @unchecked Sendable {
    public lazy var pub = source.share()
    
    let source = PassthroughSubject<Output, Never>()
}
