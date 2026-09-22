import libthreemaSwift

extension BackupRestoreLoop {
    public static let identityDataInstruction = BackupRestoreLoop.instruction(
        BackupRestoreInstruction(
            identityData: .init(
                userIdentity: "ECHOECHO",
                clientKey: ClientKey(repeating: 0, count: 32),
                cspServerGroup: "ae"
            ),
            stateUpdate: nil,
            readInstruction: nil
        )
    )

    public static func stateUpdateInstruction(_ update: BackupRestoreStateUpdate) -> BackupRestoreLoop {
        BackupRestoreLoop.instruction(
            BackupRestoreInstruction(
                identityData: nil,
                stateUpdate: update,
                readInstruction: nil
            )
        )
    }

    public static func remoteReadInstruction() -> BackupRestoreLoop {
        BackupRestoreLoop.instruction(
            BackupRestoreInstruction(
                identityData: nil,
                stateUpdate: nil,
                readInstruction: .remote
            )
        )
    }

    public static func localReadInstruction(offset: UInt64, length: UInt64) -> BackupRestoreLoop {
        BackupRestoreLoop.instruction(
            BackupRestoreInstruction(
                identityData: nil,
                stateUpdate: nil,
                readInstruction: ReadInstruction.local(
                    LocalReadInstruction(offset: StreamOffset(offset: offset), length: length)
                )
            )
        )
    }
}
