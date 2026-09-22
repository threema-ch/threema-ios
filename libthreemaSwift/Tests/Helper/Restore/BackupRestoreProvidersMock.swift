import libthreemaSwift

extension BackupRestoreProviders {
    public static var mock: BackupRestoreProviders {
        BackupRestoreProviders(
            userProfile: UserProfileProviderMock(
                userProfile: .init(
                    nickname: "",
                    profilePicture: nil,
                    profilePictureSharePolicy: .everyone,
                    linkedPhoneNumber: nil,
                    linkedEmailAddress: nil,
                    workAvailabilityStatus: nil
                )
            ),
            settings: SettingsProviderMock(
                settings: .init(
                    contactSyncPolicy: .sync,
                    unknownContactPolicy: .allowUnknown,
                    readReceiptPolicy: .sendReadReceipt,
                    typingIndicatorPolicy: .sendTypingIndicator,
                    o2oCallPolicy: .allowO2oCall,
                    o2oCallConnectionPolicy: .allowDirectConnection,
                    o2oCallVideoPolicy: .allowVideo,
                    groupCallPolicy: .allowGroupCall,
                    screenshotPolicy: .allowScreenshot,
                    blockedIdentities: [],
                    excludeFromSyncIdentities: []
                )
            ),
            cspNonces: NonceProviderMock(),
            contacts: ContactProviderMock(identities: [], contacts: []),
            groups: GroupProviderMock(),
            distributionLists: DistributionListProviderMock(),
            polls: PollProviderMock(),
            conversations: ConversationProviderMock(),
        )
    }
}
