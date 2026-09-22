import libthreemaSwift

extension LibthreemaSyncState {
    init?(_ importStatus: ContactEntity.ImportStatus) {
        let libthreemaSyncState: LibthreemaSyncState =
            switch importStatus {
            case .initial: .initial
            case .imported: .imported
            case .custom: .custom
            }
        self.init(rawValue: libthreemaSyncState.rawValue)
    }
}
