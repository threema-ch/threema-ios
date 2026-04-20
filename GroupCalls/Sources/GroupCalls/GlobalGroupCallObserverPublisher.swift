import CocoaLumberjackSwift
import Combine
import Foundation
import ThreemaProtocols

public final class GlobalGroupCallObserverPublisher: @unchecked Sendable {
    public lazy var groupCallListChangePublisher = source.share()
    
    let source = PassthroughSubject<GroupCallThreemaGroupModel, Never>()
}
