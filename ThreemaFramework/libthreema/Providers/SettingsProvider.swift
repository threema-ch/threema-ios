import Foundation
import libthreemaSwift
import ThreemaEssentials

final class SettingsProvider: libthreemaSwift.SettingsProvider {
    private nonisolated(unsafe) let userSettings: any UserSettingsProtocol
    private let userIdentity: ThreemaIdentity

    public init(
        userIdentity: ThreemaIdentity,
        userSettings: any UserSettingsProtocol
    ) {
        self.userIdentity = userIdentity
        self.userSettings = userSettings
    }

    func get() throws -> libthreemaSwift.Settings {
        libthreemaSwift.Settings(
            contactSyncPolicy: userSettings.syncContacts ? .sync : .notSynced,
            unknownContactPolicy: userSettings.blockUnknown ? .blockUnknown : .allowUnknown,
            readReceiptPolicy: userSettings.sendReadReceipts ? .sendReadReceipt : .dontSendReadReceipt,
            typingIndicatorPolicy: userSettings.sendTypingIndicator ? .sendTypingIndicator : .dontSendTypingIndicator,
            o2oCallPolicy: userSettings.enableThreemaCall ? .allowO2oCall : .denyO2oCall,
            o2oCallConnectionPolicy: userSettings.alwaysRelayCalls ? .requireRelayedConnection : .allowDirectConnection,
            o2oCallVideoPolicy: userSettings.enableVideoCall ? .allowVideo : .denyVideo,
            groupCallPolicy: userSettings.enableThreemaGroupCalls ? .allowGroupCall : .denyGroupCall,
            screenshotPolicy: userSettings.allowScreenshot ? .allowScreenshot : .denyScreenshot,
            blockedIdentities: userSettings.blacklist.array as? [String] ?? [],
            excludeFromSyncIdentities: userSettings.syncExclusionList ?? []
        )
    }

    func set(settings: libthreemaSwift.Settings) throws {
        let settingsUpdate = SettingsUpdate(
            contactSyncPolicy: settings.contactSyncPolicy,
            unknownContactPolicy: settings.unknownContactPolicy,
            readReceiptPolicy: settings.readReceiptPolicy,
            typingIndicatorPolicy: settings.typingIndicatorPolicy,
            o2oCallPolicy: settings.o2oCallPolicy,
            o2oCallConnectionPolicy: settings.o2oCallConnectionPolicy,
            o2oCallVideoPolicy: settings.o2oCallVideoPolicy,
            groupCallPolicy: settings.groupCallPolicy,
            screenshotPolicy: settings.screenshotPolicy,
            blockedIdentities: settings.blockedIdentities,
            excludeFromSyncIdentities: settings.excludeFromSyncIdentities
        )

        try update(update: settingsUpdate)
    }

    func update(update: libthreemaSwift.SettingsUpdate) throws {
        if update.blockedIdentities?.contains(userIdentity.rawValue) == true {
            throw ProviderError.InvalidParameter("Error: Blocked identities must not contain the user's own identity.")
        }

        if update.excludeFromSyncIdentities?.contains(userIdentity.rawValue) == true {
            throw ProviderError.InvalidParameter("Error: Excluded identities must not contain the user's own identity.")
        }

        if let policy = update.contactSyncPolicy {
            userSettings.syncContacts = policy == .sync
        }
        if let policy = update.unknownContactPolicy {
            userSettings.blockUnknown = policy == .blockUnknown
        }
        if let policy = update.readReceiptPolicy {
            userSettings.sendReadReceipts = policy == .sendReadReceipt
        }
        if let policy = update.typingIndicatorPolicy {
            userSettings.sendTypingIndicator = policy == .sendTypingIndicator
        }
        if let policy = update.o2oCallPolicy {
            userSettings.enableThreemaCall = policy == .allowO2oCall
        }
        if let policy = update.o2oCallConnectionPolicy {
            userSettings.alwaysRelayCalls = policy == .requireRelayedConnection
        }
        if let policy = update.o2oCallVideoPolicy {
            userSettings.enableVideoCall = policy == .allowVideo
        }
        if let policy = update.groupCallPolicy {
            userSettings.enableThreemaGroupCalls = policy == .allowGroupCall
        }
        if let blockedIdentities = update.blockedIdentities {
            userSettings.blacklist = NSOrderedSet(array: blockedIdentities)
        }
        if let excludeFromSyncIdentities = update.excludeFromSyncIdentities {
            userSettings.syncExclusionList = excludeFromSyncIdentities
        }
        if let policy = update.screenshotPolicy {
            userSettings.allowScreenshot = policy == .allowScreenshot
        }
    }
}
