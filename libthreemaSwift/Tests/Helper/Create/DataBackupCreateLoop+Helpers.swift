import Foundation
import libthreemaSwift

extension DataBackupCreateLoop {
    public static func writeAtInstruction(count: Int) -> DataBackupCreateLoop {
        DataBackupCreateLoop.instruction(
            DataBackupCreateInstruction(
                stateUpdate: nil,
                writeInstruction: .local(.writeAt(offset: 0, data: Data(repeating: 1, count: count)))
            )
        )
    }

    public static func writeAppendInstruction(count: Int) -> DataBackupCreateLoop {
        DataBackupCreateLoop.instruction(
            DataBackupCreateInstruction(
                stateUpdate: nil,
                writeInstruction: .local(.append(Data(repeating: 1, count: count)))
            )
        )
    }

    public static func stateUpdateInstruction(state: DataBackupCreateStateUpdate) -> DataBackupCreateLoop {
        DataBackupCreateLoop.instruction(
            DataBackupCreateInstruction(stateUpdate: state, writeInstruction: nil)
        )
    }
}
