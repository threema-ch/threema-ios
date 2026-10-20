import libthreemaSwift

public protocol DataRestoreDelegate: AnyObject, Sendable {
    func dataRestore(_ dataRestore: DataRestore, didReceiveIdentityData data: IdentityData) throws
    func dataRestore(_ dataRestore: DataRestore, didReceiveStateUpdate update: DataBackupRestoreStateUpdate)
}
