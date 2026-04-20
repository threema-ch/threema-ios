public final class UserSettingsMock: NSObject, UserSettingsProtocol {
    override public init() {
        // no-op
    }

    public init(
        blacklist: [Any]? = nil,
        enableIPv6: Bool = false,
        enableMultiDevice: Bool = false,
        blockUnknown: Bool = false,
        videoQuality: String = "original"
    ) {
        if let blacklist {
            self.blacklist = NSOrderedSet(array: blacklist)
        }
        self.enableIPv6 = enableIPv6
        self.enableMultiDevice = enableMultiDevice
        self.blockUnknown = blockUnknown
        self.videoQuality = videoQuality
    }

    public var appMigratedToVersion = 0

    public var wallpaper: Data?

    public var disableBigEmojis = true

    public var sendMessageFeedback = true

    public var chatFontSize: Float = 0.0

    public var enableIPv6 = true

    public var syncContacts = false

    public var blockUnknown = false

    public var enablePoi = true

    public var allowOutgoingDonations = false

    public var sendReadReceipts = true

    public var sendTypingIndicator = true

    public var includeCallsInRecents = true

    public var enableVideoCall = true

    public var threemaVideoCallQualitySetting: ThreemaVideoCallQualitySetting = .init(0)

    public var enableThreemaCall = true

    public var alwaysRelayCalls = true

    public var enableThreemaGroupCalls = true

    public var blacklist: NSOrderedSet? = []

    public var syncExclusionList: [Any]? = [Any]()

    public var hideStaleContacts = false

    public var sortOrderFirstName = true

    public var sendProfilePicture: SendProfilePicture = .init(0)

    public var profilePictureContactList: [Any]?

    public var autoSaveMedia = false

    public var inAppSounds = true

    public var inAppVibrate = true

    public var inAppPreview = true

    public var notificationType: NSNumber? = 0

    public var imageSize: String?
    public var videoQuality: String?
    public var voIPSound: String?
    public var pushSound: String?
    public var pushGroupSound: String?
    public var pushDecrypt = false
    public var pushSettings = [Any]()
    public var enableMasterDnd = false
    public var masterDndWorkingDays: NSOrderedSet? = []
    public var masterDndStartTime: String?
    public var masterDndEndTime: String?

    public var hidePrivateChats = false

    public var enableMultiDevice = false
    public var allowSeveralLinkedDevices = false
    public var workIdentities: NSOrderedSet?
    public var profilePictureRequestList: [Any]?
    public var blockCommunication = false
    public var donateInteractions = false

    public var voiceMessagesShowTimeRemaining = false

    public var disableProximityMonitoring = false

    public var validationLogging = false

    public var sentryAppDevice: String?

    public var groupCallsDeveloper = false

    public var groupCallsDebugMessages = false

    public var keepMessagesDays = -1

    public var safeConfig: Data?

    public var safeIntroShown = false

    public var contactList2 = false

    public var sendEmojiReactions = false

    public var ipcCommunicationEnabled = true

    public var ipcSecretPrefix: Data?
    
    public var companyDirectory = false

    public var interfaceStyle = 0

    public var showProfilePictures = true

    public var displayOrderFirstName = true

    public var showGalleryPreview = true

    public var previewLimit: Float = 0.0
    
    public var wallpaperType: WallpaperType = .threema
    
    public var showWorkReferral = false
}
