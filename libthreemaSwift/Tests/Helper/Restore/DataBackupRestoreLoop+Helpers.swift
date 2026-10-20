import libthreemaSwift

extension DataBackupRestoreLoop {
    public static let identityDataInstruction = DataBackupRestoreLoop.instruction(
        DataBackupRestoreInstruction(
            identityData: .init(
                userIdentity: "ECHOECHO",
                clientKey: ClientKey(repeating: 0, count: 32),
                cspServerGroup: "ae"
            ),
            stateUpdate: nil,
            readInstruction: nil
        )
    )

    public static func stateUpdateInstruction(_ update: DataBackupRestoreStateUpdate) -> DataBackupRestoreLoop {
        DataBackupRestoreLoop.instruction(
            DataBackupRestoreInstruction(
                identityData: nil,
                stateUpdate: update,
                readInstruction: nil
            )
        )
    }

    public static func localReadInstruction(offset: UInt64, length: UInt32) -> DataBackupRestoreLoop {
        DataBackupRestoreLoop.instruction(
            DataBackupRestoreInstruction(
                identityData: nil,
                stateUpdate: nil,
                readInstruction: DataBackupRestoreReadInstruction.local(
                    DataBackupRestoreLocalReadInstruction(offset: StreamOffset(offset), length: length)
                )
            )
        )
    }
}
