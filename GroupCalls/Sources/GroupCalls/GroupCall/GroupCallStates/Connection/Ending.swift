import CocoaLumberjackSwift
import Foundation

@GlobalGroupCallActor
struct Ending: GroupCallState {

    // MARK: - Private properties
    
    private let groupCallActor: GroupCallActor
    private let groupCallContext: GroupCallContextProtocol?

    // MARK: - Lifecycle

    init(groupCallActor: GroupCallActor, groupCallContext: GroupCallContextProtocol? = nil) {
        // TODO: (IOS-3857) Logging
        DDLogNotice("[GroupCall] Init Ending \(groupCallActor.callID)")
        self.groupCallActor = groupCallActor
        self.groupCallContext = groupCallContext
    }
    
    // MARK: - GroupCallState
    
    // Force continue to ended if this doesn't complete in 10s or something so we don't get
    // stuck in this state...
    func next() async throws -> GroupCallState? {
        DDLogNotice("[GroupCall] Ending `next()` in \(groupCallActor.callID)")
        
        /// **Leave Call** 5. Do full cleanups

        /// 5.1 We start with the `GroupCallViewModel`, this also dismisses the UI
        await groupCallActor.viewModel.leaveCall()
        
        /// 5.2 We continue with the context
        await groupCallContext?.leave()
                
        return Ended()
    }
}
