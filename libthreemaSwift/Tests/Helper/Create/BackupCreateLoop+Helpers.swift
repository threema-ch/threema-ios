import Foundation
import libthreemaSwift

extension BackupCreateLoop {
    public static func writeAtInstruction(count: Int) -> BackupCreateLoop {
        BackupCreateLoop.instruction(
            BackupCreateInstruction(
                writeInstruction: .local(.writeAt(offset: 0, data: Data(repeating: 1, count: count))),
                stateUpdate: nil
            )
        )
    }

    public static func writeAppendInstruction(count: Int) -> BackupCreateLoop {
        BackupCreateLoop.instruction(
            BackupCreateInstruction(
                writeInstruction: .local(.append(Data(repeating: 1, count: count))),
                stateUpdate: nil
            )
        )
    }

    public static func writeRemoteInstruction() -> BackupCreateLoop {
        BackupCreateLoop.instruction(
            BackupCreateInstruction(writeInstruction: .remote, stateUpdate: nil)
        )
    }

    public static func stateUpdateInstruction(state: BackupCreateStateUpdate) -> BackupCreateLoop {
        BackupCreateLoop.instruction(
            BackupCreateInstruction(writeInstruction: nil, stateUpdate: state)
        )
    }
}
