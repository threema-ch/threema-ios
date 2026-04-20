import Foundation
import ThreemaProtocols
@testable import ThreemaFramework

final class SettingsStoreMock: SettingsStoreProtocol, SettingsStoreInternalProtocol {
    var inAppSounds = true

    var inAppVibrate = true
    
    var displayOrderFirstName = true

    var hideStaleContacts = false

    var previewLimit: Float = 0.0

    var showGalleryPreview = true

    var showProfilePictures = true

    var interfaceStyle = 0

    var syncContacts = true
    
    var blacklist = Set<String>()
    
    var syncExclusionList = [String]()
    
    var blockUnknown = true
    
    var allowOutgoingDonations = false

    var sendReadReceipts = true
    
    var sendTypingIndicator = true
    
    var choosePOI = true
    
    var hidePrivateChats = true
    
    var enableMasterDnd = false
    
    var masterDndWorkingDays: Set<Int> = []
    
    var masterDndStartTime: String?
    
    var masterDndEndTime: String?
    
    var notificationType: ThreemaFramework.NotificationType = .restrictive

    var pushShowPreview = false
    
    var wallpaperStore: WallpaperStoreProtocol = WallpaperStoreMock()

    var useBigEmojis = false
    
    var sendMessageFeedback = false
    
    var imageSize: String = ImageSenderItemSize.original.rawValue

    var videoQuality: String = VideoSenderItemQuality.original.rawValue

    var autoSaveMedia = false
    
    var enableThreemaCall = true
    
    var alwaysRelayCalls = false
    
    var includeCallsInRecents = true
    
    var enableVideoCall = true
    
    var threemaVideoCallQualitySetting = ThreemaVideoCallQualitySetting(2)
    
    var voIPSound = "Test Sound"
    
    var enableThreemaGroupCalls = true

    var isMultiDeviceRegistered = false
    
    var enableIPv6 = true
    
    var enableProximityMonitoring = true
    
    var validationLogging = false
    
    var sentryAppDevice: String?
    
    var ipcCommunicationEnabled = false

    func updateSettingsStore(with syncSettings: Sync_Settings) {
        // Noop
    }

    func syncSettingCalls() {
        // no-op
    }
}
