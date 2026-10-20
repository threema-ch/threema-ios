import Foundation
import libthreemaSwift
import Testing
import ThreemaEssentials

@testable import ThreemaFramework

@MainActor
@Suite("Settings Provider Unit Tests")
struct SettingsProviderTests {

    // MARK: - get()

    @Test func getUnknownContactPolicyBlockUnknownWhenBlockUnknown() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.blockUnknown = true
        #expect(try sut.get().unknownContactPolicy == .blockUnknown)

        settings.blockUnknown = false
        #expect(try sut.get().unknownContactPolicy == .allowUnknown)
    }

    @Test func getReadReceiptPolicySendReadReceiptWhenSendReadReceipts() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.sendReadReceipts = true
        #expect(try sut.get().readReceiptPolicy == .sendReadReceipt)

        settings.sendReadReceipts = false
        #expect(try sut.get().readReceiptPolicy == .dontSendReadReceipt)
    }

    @Test func getTypingIndicatorPolicySendTypingIndicatorWhenSendTypingIndicator() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.sendTypingIndicator = true
        #expect(try sut.get().typingIndicatorPolicy == .sendTypingIndicator)

        settings.sendTypingIndicator = false
        #expect(try sut.get().typingIndicatorPolicy == .dontSendTypingIndicator)
    }

    @Test func getO2oCallPolicyAllowWhenEnableThreemaCall() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.enableThreemaCall = true
        #expect(try sut.get().o2oCallPolicy == .allowO2oCall)

        settings.enableThreemaCall = false
        #expect(try sut.get().o2oCallPolicy == .denyO2oCall)
    }

    @Test func getO2oCallConnectionPolicyRequireRelayedWhenAlwaysRelayCalls() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.alwaysRelayCalls = true
        #expect(try sut.get().o2oCallConnectionPolicy == .requireRelayedConnection)

        settings.alwaysRelayCalls = false
        #expect(try sut.get().o2oCallConnectionPolicy == .allowDirectConnection)
    }

    @Test func getO2oCallVideoPolicyAllowVideoWhenEnableVideoCall() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.enableVideoCall = true
        #expect(try sut.get().o2oCallVideoPolicy == .allowVideo)

        settings.enableVideoCall = false
        #expect(try sut.get().o2oCallVideoPolicy == .denyVideo)
    }

    @Test func getGroupCallPolicyAllowWhenEnableThreemaGroupCalls() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.enableThreemaGroupCalls = true
        #expect(try sut.get().groupCallPolicy == .allowGroupCall)

        settings.enableThreemaGroupCalls = false
        #expect(try sut.get().groupCallPolicy == .denyGroupCall)
    }

    @Test func getScreenshotPolicyAllowWhenAllowScreenshot() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.allowScreenshot = true
        #expect(try sut.get().screenshotPolicy == .allowScreenshot)

        settings.allowScreenshot = false
        #expect(try sut.get().screenshotPolicy == .denyScreenshot)
    }

    @Test func getBlockedIdentities() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.blacklist = NSOrderedSet()
        #expect(try sut.get().blockedIdentities.isEmpty)

        settings.blacklist = NSOrderedSet(array: [1, 3, 4, 5])
        #expect(try sut.get().blockedIdentities.isEmpty)

        settings.blacklist = NSOrderedSet(array: ["AAAAAAAA", "BBBBBBBB", "CCCCCCCC"])
        #expect(try sut.get().blockedIdentities == ["AAAAAAAA", "BBBBBBBB", "CCCCCCCC"])
    }

    @Test func getExcludeFromSyncIdentities() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.syncExclusionList = nil
        #expect(try sut.get().excludeFromSyncIdentities.isEmpty)

        settings.syncExclusionList = []
        #expect(try sut.get().excludeFromSyncIdentities.isEmpty)

        settings.syncExclusionList = ["AAAAAAAA", "BBBBBBBB", "CCCCCCCC"]
        #expect(try sut.get().excludeFromSyncIdentities == ["AAAAAAAA", "BBBBBBBB", "CCCCCCCC"])
    }

    // MARK: - set(settings:)

    @Test func set() throws {
        let userSettings = UserSettingsMock()
        userSettings.allowScreenshot = true
        userSettings.syncContacts = true
        userSettings.blockUnknown = true
        userSettings.sendReadReceipts = true
        userSettings.sendTypingIndicator = true
        userSettings.enableThreemaCall = true
        userSettings.alwaysRelayCalls = true
        userSettings.enableVideoCall = true
        userSettings.enableThreemaGroupCalls = true
        userSettings.blacklist = []
        userSettings.syncExclusionList = []

        let sut = makeSUT(userIdentity: ThreemaIdentity("AAAAAAAA"), userSettings: userSettings)

        var settings = libthreemaSwift.Settings(
            unknownContactPolicy: .allowUnknown,
            readReceiptPolicy: .dontSendReadReceipt,
            typingIndicatorPolicy: .dontSendTypingIndicator,
            o2oCallPolicy: .denyO2oCall,
            o2oCallConnectionPolicy: .allowDirectConnection,
            o2oCallVideoPolicy: .denyVideo,
            groupCallPolicy: .denyGroupCall,
            screenshotPolicy: .denyScreenshot,
            blockedIdentities: ["BBBBBBBB", "CCCCCCCC"],
            excludeFromSyncIdentities: ["DDDDDDDD", "EEEEEEEE"]
        )

        try sut.set(settings: settings)

        #expect(userSettings.allowScreenshot == false)
        #expect(userSettings.syncContacts == true)
        #expect(userSettings.blockUnknown == false)
        #expect(userSettings.sendReadReceipts == false)
        #expect(userSettings.sendTypingIndicator == false)
        #expect(userSettings.enableThreemaCall == false)
        #expect(userSettings.alwaysRelayCalls == false)
        #expect(userSettings.enableVideoCall == false)
        #expect(userSettings.enableThreemaGroupCalls == false)
        #expect(userSettings.blacklist?.set == Set(["BBBBBBBB", "CCCCCCCC"]))
        #expect(try Set(#require(userSettings.syncExclusionList)) == Set(["DDDDDDDD", "EEEEEEEE"]))

        settings = libthreemaSwift.Settings(
            unknownContactPolicy: .blockUnknown,
            readReceiptPolicy: .sendReadReceipt,
            typingIndicatorPolicy: .sendTypingIndicator,
            o2oCallPolicy: .allowO2oCall,
            o2oCallConnectionPolicy: .requireRelayedConnection,
            o2oCallVideoPolicy: .allowVideo,
            groupCallPolicy: .allowGroupCall,
            screenshotPolicy: .allowScreenshot,
            blockedIdentities: [],
            excludeFromSyncIdentities: []
        )

        try sut.set(settings: settings)

        #expect(userSettings.allowScreenshot == true)
        #expect(userSettings.syncContacts == true)
        #expect(userSettings.blockUnknown == true)
        #expect(userSettings.sendReadReceipts == true)
        #expect(userSettings.sendTypingIndicator == true)
        #expect(userSettings.enableThreemaCall == true)
        #expect(userSettings.alwaysRelayCalls == true)
        #expect(userSettings.enableVideoCall == true)
        #expect(userSettings.enableThreemaGroupCalls == true)
        #expect(userSettings.blacklist == [])
        #expect(userSettings.syncExclusionList == [])
    }

    // MARK: - update(update:)

    @Test func updateThrowsInvalidParameterWhenBlockedIdentitiesContainsUserIdentity() throws {
        let sut = makeSUT(userIdentity: ThreemaIdentity("AAAAAAAA"))

        let update = libthreemaSwift.SettingsUpdate(
            unknownContactPolicy: nil,
            readReceiptPolicy: nil,
            typingIndicatorPolicy: nil,
            o2oCallPolicy: nil,
            o2oCallConnectionPolicy: nil,
            o2oCallVideoPolicy: nil,
            groupCallPolicy: nil,
            screenshotPolicy: nil,
            blockedIdentities: ["AAAAAAAA", "BBBBBBBB"],
            excludeFromSyncIdentities: nil
        )

        let expectedError = ProviderError.ConversionError(
            "Error: Blocked identities must not contain the user's own identity."
        )

        #expect(throws: expectedError) { try sut.update(update: update) }
    }

    @Test func updateThrowsInvalidParameterWhenExcludeFromSyncIdentitiesContainsUserIdentity() throws {
        let sut = makeSUT(userIdentity: ThreemaIdentity("AAAAAAAA"))

        let update = libthreemaSwift.SettingsUpdate(
            unknownContactPolicy: nil,
            readReceiptPolicy: nil,
            typingIndicatorPolicy: nil,
            o2oCallPolicy: nil,
            o2oCallConnectionPolicy: nil,
            o2oCallVideoPolicy: nil,
            groupCallPolicy: nil,
            screenshotPolicy: nil,
            blockedIdentities: nil,
            excludeFromSyncIdentities: ["AAAAAAAA", "BBBBBBBB"]
        )

        let expectedError = ProviderError.ConversionError(
            "Error: Excluded identities must not contain the user's own identity."
        )

        #expect(throws: expectedError) { try sut.update(update: update) }
    }

    @Test func updateUnknownContactPolicyBlockUnknownSetsBlockUnknown() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.blockUnknown = true
        try sut.update(update: .testUpdate(unknownContactPolicy: nil))
        #expect(settings.blockUnknown == true)

        settings.blockUnknown = false
        try sut.update(update: .testUpdate(unknownContactPolicy: nil))
        #expect(settings.blockUnknown == false)

        settings.syncContacts = false
        try sut.update(update: .testUpdate(unknownContactPolicy: .blockUnknown))
        #expect(settings.blockUnknown == true)

        settings.syncContacts = true
        try sut.update(update: .testUpdate(unknownContactPolicy: .allowUnknown))
        #expect(settings.blockUnknown == false)
    }

    @Test func updateReadReceiptPolicySendSetsSendReadReceipts() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.sendReadReceipts = true
        try sut.update(update: .testUpdate(readReceiptPolicy: nil))
        #expect(settings.sendReadReceipts == true)

        settings.sendReadReceipts = false
        try sut.update(update: .testUpdate(readReceiptPolicy: nil))
        #expect(settings.sendReadReceipts == false)

        settings.sendReadReceipts = false
        try sut.update(update: .testUpdate(readReceiptPolicy: .sendReadReceipt))
        #expect(settings.sendReadReceipts == true)

        settings.sendReadReceipts = true
        try sut.update(update: .testUpdate(readReceiptPolicy: .dontSendReadReceipt))
        #expect(settings.sendReadReceipts == false)
    }

    @Test func updateTypingIndicatorPolicySendSetsSendTypingIndicator() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.sendTypingIndicator = true
        try sut.update(update: .testUpdate(typingIndicatorPolicy: nil))
        #expect(settings.sendTypingIndicator == true)

        settings.sendTypingIndicator = false
        try sut.update(update: .testUpdate(typingIndicatorPolicy: nil))
        #expect(settings.sendTypingIndicator == false)

        settings.sendTypingIndicator = false
        try sut.update(update: .testUpdate(typingIndicatorPolicy: .sendTypingIndicator))
        #expect(settings.sendTypingIndicator == true)

        settings.sendTypingIndicator = true
        try sut.update(update: .testUpdate(typingIndicatorPolicy: .dontSendTypingIndicator))
        #expect(settings.sendTypingIndicator == false)
    }

    @Test func updateO2oCallPolicyAllowSetsEnableThreemaCall() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.enableThreemaCall = true
        try sut.update(update: .testUpdate(o2oCallPolicy: nil))
        #expect(settings.enableThreemaCall == true)

        settings.enableThreemaCall = false
        try sut.update(update: .testUpdate(o2oCallPolicy: nil))
        #expect(settings.enableThreemaCall == false)

        settings.enableThreemaCall = false
        try sut.update(update: .testUpdate(o2oCallPolicy: .allowO2oCall))
        #expect(settings.enableThreemaCall == true)

        settings.enableThreemaCall = true
        try sut.update(update: .testUpdate(o2oCallPolicy: .denyO2oCall))
        #expect(settings.enableThreemaCall == false)
    }

    @Test func updateO2oCallConnectionPolicyRequireRelayedSetsAlwaysRelayCalls() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.alwaysRelayCalls = true
        try sut.update(update: .testUpdate(o2oCallConnectionPolicy: nil))
        #expect(settings.alwaysRelayCalls == true)

        settings.alwaysRelayCalls = false
        try sut.update(update: .testUpdate(o2oCallConnectionPolicy: nil))
        #expect(settings.alwaysRelayCalls == false)

        settings.alwaysRelayCalls = false
        try sut.update(update: .testUpdate(o2oCallConnectionPolicy: .requireRelayedConnection))
        #expect(settings.alwaysRelayCalls == true)

        settings.alwaysRelayCalls = true
        try sut.update(update: .testUpdate(o2oCallConnectionPolicy: .allowDirectConnection))
        #expect(settings.alwaysRelayCalls == false)
    }

    @Test func updateO2oCallVideoPolicyAllowVideoSetsEnableVideoCall() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.enableVideoCall = true
        try sut.update(update: .testUpdate(o2oCallVideoPolicy: nil))
        #expect(settings.enableVideoCall == true)

        settings.enableVideoCall = false
        try sut.update(update: .testUpdate(o2oCallVideoPolicy: nil))
        #expect(settings.enableVideoCall == false)

        settings.enableVideoCall = false
        try sut.update(update: .testUpdate(o2oCallVideoPolicy: .allowVideo))
        #expect(settings.enableVideoCall == true)

        settings.enableVideoCall = true
        try sut.update(update: .testUpdate(o2oCallVideoPolicy: .denyVideo))
        #expect(settings.enableVideoCall == false)
    }

    @Test func updateGroupCallPolicyAllowSetsEnableThreemaGroupCalls() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.enableThreemaGroupCalls = true
        try sut.update(update: .testUpdate(groupCallPolicy: nil))
        #expect(settings.enableThreemaGroupCalls == true)

        settings.enableThreemaGroupCalls = false
        try sut.update(update: .testUpdate(groupCallPolicy: nil))
        #expect(settings.enableThreemaGroupCalls == false)

        settings.enableThreemaGroupCalls = false
        try sut.update(update: .testUpdate(groupCallPolicy: .allowGroupCall))
        #expect(settings.enableThreemaGroupCalls == true)

        settings.enableThreemaGroupCalls = true
        try sut.update(update: .testUpdate(groupCallPolicy: .denyGroupCall))
        #expect(settings.enableThreemaGroupCalls == false)
    }

    @Test func updateScreenshotPolicyDenySetsAllowScreenshot() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        settings.allowScreenshot = true
        try sut.update(update: .testUpdate(screenshotPolicy: nil))
        #expect(settings.allowScreenshot == true)

        settings.allowScreenshot = false
        try sut.update(update: .testUpdate(screenshotPolicy: nil))
        #expect(settings.allowScreenshot == false)

        settings.allowScreenshot = false
        try sut.update(update: .testUpdate(screenshotPolicy: .allowScreenshot))
        #expect(settings.allowScreenshot == true)

        settings.allowScreenshot = true
        try sut.update(update: .testUpdate(screenshotPolicy: .denyScreenshot))
        #expect(settings.allowScreenshot == false)
    }

    @Test func updateNilBlockedIdentitiesDoesNotChangeBlacklist() throws {
        let settings = UserSettingsMock()
        settings.blacklist = NSOrderedSet(array: ["XXXXXXXX"])
        let sut = makeSUT(userSettings: settings)

        try sut.update(update: .testUpdate(blockedIdentities: nil))
        #expect(settings.blacklist == NSOrderedSet(array: ["XXXXXXXX"]))
    }

    @Test func updateEmptyBlockedIdentitiesClearsBlacklist() throws {
        let settings = UserSettingsMock()
        settings.blacklist = NSOrderedSet(array: ["XXXXXXXX"])
        let sut = makeSUT(userSettings: settings)

        try sut.update(update: .testUpdate(blockedIdentities: []))
        #expect(settings.blacklist == NSOrderedSet())
    }

    @Test func updateBlockedIdentitiesReplacesBlacklist() throws {
        let settings = UserSettingsMock()
        settings.blacklist = NSOrderedSet(array: ["XXXXXXXX"])
        let sut = makeSUT(userSettings: settings)

        try sut.update(update: .testUpdate(blockedIdentities: ["BBBBBBBB", "CCCCCCCC"]))
        #expect(settings.blacklist?.set == Set(["BBBBBBBB", "CCCCCCCC"]))
    }

    @Test func updateBlockedIdentitiesDeduplicatedIntoSet() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        try sut.update(update: .testUpdate(blockedIdentities: ["BBBBBBBB", "BBBBBBBB", "CCCCCCCC"]))
        #expect(settings.blacklist?.set == Set(["BBBBBBBB", "CCCCCCCC"]))
    }

    @Test func updateNilExcludeFromSyncIdentitiesDoesNotChangeSyncExclusionList() throws {
        let settings = UserSettingsMock()
        settings.syncExclusionList = ["XXXXXXXX"]
        let sut = makeSUT(userSettings: settings)

        try sut.update(update: .testUpdate(excludeFromSyncIdentities: nil))
        #expect(settings.syncExclusionList == ["XXXXXXXX"])
    }

    @Test func updateEmptyExcludeFromSyncIdentitiesClearsSyncExclusionList() throws {
        let settings = UserSettingsMock()
        settings.syncExclusionList = ["XXXXXXXX"]
        let sut = makeSUT(userSettings: settings)

        try sut.update(update: .testUpdate(excludeFromSyncIdentities: []))
        #expect(settings.syncExclusionList?.isEmpty == true)
    }

    @Test func updateExcludeFromSyncIdentitiesReplacesSyncExclusionList() throws {
        let settings = UserSettingsMock()
        settings.syncExclusionList = ["XXXXXXXX"]
        let sut = makeSUT(userSettings: settings)

        try sut.update(update: .testUpdate(excludeFromSyncIdentities: ["BBBBBBBB", "CCCCCCCC"]))
        #expect(try Set(#require(settings.syncExclusionList)) == Set(["BBBBBBBB", "CCCCCCCC"]))
    }

    @Test func updateAllNilFieldsMakesNoChanges() throws {
        let settings = UserSettingsMock()
        settings.syncContacts = true
        settings.blockUnknown = true
        settings.sendReadReceipts = false
        settings.sendTypingIndicator = false
        settings.enableThreemaCall = false
        settings.alwaysRelayCalls = false
        settings.enableVideoCall = false
        settings.enableThreemaGroupCalls = false
        settings.allowScreenshot = false
        settings.blacklist = NSOrderedSet(array: ["XXXXXXXX"])
        settings.syncExclusionList = ["YYYYYYYY"]
        let sut = makeSUT(userSettings: settings)

        try sut.update(update: .testUpdate())

        #expect(settings.syncContacts == true)
        #expect(settings.blockUnknown == true)
        #expect(settings.sendReadReceipts == false)
        #expect(settings.sendTypingIndicator == false)
        #expect(settings.enableThreemaCall == false)
        #expect(settings.alwaysRelayCalls == false)
        #expect(settings.enableVideoCall == false)
        #expect(settings.enableThreemaGroupCalls == false)
        #expect(settings.allowScreenshot == false)
        #expect(settings.blacklist == NSOrderedSet(array: ["XXXXXXXX"]))
        #expect(settings.syncExclusionList == ["YYYYYYYY"])
    }

    @Test func updateFullyPopulatedAppliesEveryField() throws {
        let settings = UserSettingsMock()
        let sut = makeSUT(userSettings: settings)

        try sut.update(update: .testUpdate(
            unknownContactPolicy: .blockUnknown,
            readReceiptPolicy: .sendReadReceipt,
            typingIndicatorPolicy: .sendTypingIndicator,
            o2oCallPolicy: .allowO2oCall,
            o2oCallConnectionPolicy: .requireRelayedConnection,
            o2oCallVideoPolicy: .allowVideo,
            groupCallPolicy: .allowGroupCall,
            screenshotPolicy: .allowScreenshot,
            blockedIdentities: ["BBBBBBBB"],
            excludeFromSyncIdentities: ["CCCCCCCC"]
        ))

        #expect(settings.syncContacts == false)
        #expect(settings.blockUnknown == true)
        #expect(settings.sendReadReceipts == true)
        #expect(settings.sendTypingIndicator == true)
        #expect(settings.enableThreemaCall == true)
        #expect(settings.alwaysRelayCalls == true)
        #expect(settings.enableVideoCall == true)
        #expect(settings.enableThreemaGroupCalls == true)
        #expect(settings.allowScreenshot == true)
        #expect(settings.blacklist == NSOrderedSet(array: ["BBBBBBBB"]))
        #expect(settings.syncExclusionList == ["CCCCCCCC"])
    }

    // MARK: - Private methods

    private func makeSUT(
        userIdentity: ThreemaIdentity = ThreemaIdentity("AAAAAAAA"),
        userSettings: any UserSettingsProtocol = .mock
    ) -> ThreemaFramework.SettingsProvider {
        SettingsProvider(userIdentity: userIdentity, userSettings: userSettings)
    }
}

extension libthreemaSwift.SettingsUpdate {
    fileprivate static func testUpdate(
        unknownContactPolicy: UnknownContactPolicy? = nil,
        readReceiptPolicy: ReadReceiptPolicy? = nil,
        typingIndicatorPolicy: TypingIndicatorPolicy? = nil,
        o2oCallPolicy: O2oCallPolicy? = nil,
        o2oCallConnectionPolicy: O2oCallConnectionPolicy? = nil,
        o2oCallVideoPolicy: O2oCallVideoPolicy? = nil,
        groupCallPolicy: GroupCallPolicy? = nil,
        screenshotPolicy: ScreenshotPolicy? = nil,
        blockedIdentities: Set<String>? = nil,
        excludeFromSyncIdentities: Set<String>? = nil
    ) -> libthreemaSwift.SettingsUpdate {
        libthreemaSwift.SettingsUpdate(
            unknownContactPolicy: unknownContactPolicy,
            readReceiptPolicy: readReceiptPolicy,
            typingIndicatorPolicy: typingIndicatorPolicy,
            o2oCallPolicy: o2oCallPolicy,
            o2oCallConnectionPolicy: o2oCallConnectionPolicy,
            o2oCallVideoPolicy: o2oCallVideoPolicy,
            groupCallPolicy: groupCallPolicy,
            screenshotPolicy: screenshotPolicy,
            blockedIdentities: blockedIdentities,
            excludeFromSyncIdentities: excludeFromSyncIdentities
        )
    }
}
