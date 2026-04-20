import Foundation
import ThreemaProtocols

public protocol SettingsStoreProtocol {

    // Appearance
    var displayOrderFirstName: Bool { get set }
    var hideStaleContacts: Bool { get set }
    var previewLimit: Float { get set }
    var showGalleryPreview: Bool { get set }
    var showProfilePictures: Bool { get set }
    var interfaceStyle: Int { get set }

    // Privacy
    var syncContacts: Bool { get set }
    var blacklist: Set<String> { get set }
    var syncExclusionList: [String] { get set }
    var blockUnknown: Bool { get set }
    var allowOutgoingDonations: Bool { get set }
    var sendReadReceipts: Bool { get set }
    var sendTypingIndicator: Bool { get set }
    var choosePOI: Bool { get set }
    var hidePrivateChats: Bool { get set }
    
    // Notifications
    var inAppSounds: Bool { get set }
    var inAppVibrate: Bool { get set }
    var enableMasterDnd: Bool { get set }
    var masterDndWorkingDays: Set<Int> { get set }
    var masterDndStartTime: String? { get set }
    var masterDndEndTime: String? { get set }
    var notificationType: NotificationType { get set }
    var pushShowPreview: Bool { get set }
    
    // Chat
    var wallpaperStore: WallpaperStoreProtocol { get }
    var useBigEmojis: Bool { get set }
    var sendMessageFeedback: Bool { get set }

    // Media
    var imageSize: String { get set }
    var videoQuality: String { get set }
    var autoSaveMedia: Bool { get set }
    
    // Calls
    var enableThreemaCall: Bool { get set }
    var alwaysRelayCalls: Bool { get set }
    var includeCallsInRecents: Bool { get set }
    var enableVideoCall: Bool { get set }
    var threemaVideoCallQualitySetting: ThreemaVideoCallQualitySetting { get set }
    var voIPSound: String { get set }
    var enableThreemaGroupCalls: Bool { get set }
	
    // Multi Device
    var isMultiDeviceRegistered: Bool { get set }

    // Advanced
    var enableIPv6: Bool { get set }
    var validationLogging: Bool { get set }
    var sentryAppDevice: String? { get set }
    var ipcCommunicationEnabled: Bool { get set }
}

protocol SettingsStoreInternalProtocol {
    func updateSettingsStore(with syncSettings: Sync_Settings)
    func syncSettingCalls()
}
