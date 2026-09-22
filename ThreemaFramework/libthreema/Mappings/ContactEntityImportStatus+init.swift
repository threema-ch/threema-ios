import libthreemaSwift

extension ContactEntity.ImportStatus {
    init?(_ libthreemaSyncState: LibthreemaSyncState) {
        let importStatus: ContactEntity.ImportStatus =
            switch libthreemaSyncState {
            case .initial: .initial
            case .imported: .imported
            case .custom: .custom
            }
        self.init(rawValue: importStatus.rawValue)
    }
}
