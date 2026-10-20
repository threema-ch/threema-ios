import libthreemaSwift

extension DataBackupProviders {
    public static var mock: DataBackupProviders {
        DataBackupProviders(
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
            contacts: ContactProviderMock(identities: [], contacts: []),
            groups: GroupProviderMock(),
            distributionLists: DistributionListProviderMock(),
            cspNonces: NonceProviderMock(),
            polls: PollProviderMock(),
            conversations: ConversationProviderMock(),
        )
    }
}
