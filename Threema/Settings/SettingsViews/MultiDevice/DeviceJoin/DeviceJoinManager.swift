import CocoaLumberjackSwift
import Foundation

class DeviceJoinManager: ObservableObject {
    
    enum ViewState: Equatable {
        case scanQRCode
        case establishRendezvousConnection
        case verifyRendezvousConnection(rendezvousPathHash: Data)
        case sendJoinData
        case completed
    }
    
    enum Error: Swift.Error {
        case wrongNextState
    }
    
    @Published var viewState = ViewState.scanQRCode
    
    let deviceJoin = DeviceJoin(role: .existingDevice)
    
    deinit {
        DDLogVerbose("DeviceJoinManager deallocated")
    }
    
    @MainActor
    func advance(to nextViewState: ViewState) throws {
        guard viewState != nextViewState else {
            // Nothing to do
            return
        }
        
        // TODO: Verify switching to the next state is valid
        
        viewState = nextViewState
    }
    
    // MARK: Localization helper
    
    static var downloadURL: String {
        ThreemaURLProvider.deviceJoinDownloadString()
    }
}
