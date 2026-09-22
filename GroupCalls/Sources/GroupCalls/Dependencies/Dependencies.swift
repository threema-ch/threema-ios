import AudioSessionManager
import Foundation

/// Collection of various dependencies needed for the group calls SPM package
///
/// Since we're importing various dependencies we don't check for sendable.
/// When using any of these you must make sure that the use is thread safe.
///
/// These are injected from the main app and need to be mocked for testing.
/// Ideally we would be able to import those from other SPM packages as well
/// but we're not there yet.
public struct Dependencies: @unchecked Sendable {
    
    // MARK: - Internal Properties
    
    let groupCallsHTTPClientAdapter: any GroupCallHTTPClientAdapterProtocol
    let httpHelper: any GroupCallSFUTokenFetchAdapterProtocol
    let groupCallCrypto: any GroupCallCryptoProtocol
    let groupCallDateFormatter: any GroupCallDateFormatterProtocol
    let userSettings: any GroupCallUserSettingsProtocol
    let groupCallSystemMessageAdapter: any GroupCallSystemMessageAdapterProtocol
    let notificationPresenterWrapper: any NotificationPresenterWrapperProtocol
    let groupCallParticipantInfoFetcher: any GroupCallParticipantInfoFetcherProtocol
    let groupCallSessionHelper: any GroupCallSessionHelperProtocol
    let groupCallBundleUtil: any GroupCallBundleUtilProtocol
    let isRunningForScreenshots: Bool

    /// The one owner of the process-wide audio session.
    let audioSessionManager: any AudioSessionManagerProtocol

    // MARK: - Lifecycle
    
    public init(
        groupCallsHTTPClientAdapter: any GroupCallHTTPClientAdapterProtocol,
        httpHelper: any GroupCallSFUTokenFetchAdapterProtocol,
        groupCallCrypto: any GroupCallCryptoProtocol,
        groupCallDateFormatter: any GroupCallDateFormatterProtocol,
        userSettings: any GroupCallUserSettingsProtocol,
        groupCallSystemMessageAdapter: any GroupCallSystemMessageAdapterProtocol,
        notificationPresenterWrapper: any NotificationPresenterWrapperProtocol,
        groupCallParticipantInfoFetcher: any GroupCallParticipantInfoFetcherProtocol,
        groupCallSessionHelper: any GroupCallSessionHelperProtocol,
        groupCallBundleUtil: any GroupCallBundleUtilProtocol,
        isRunningForScreenshots: Bool,
        audioSessionManager: any AudioSessionManagerProtocol
    ) {
        self.groupCallsHTTPClientAdapter = groupCallsHTTPClientAdapter
        self.httpHelper = httpHelper
        self.groupCallCrypto = groupCallCrypto
        self.groupCallDateFormatter = groupCallDateFormatter
        self.userSettings = userSettings
        self.groupCallSystemMessageAdapter = groupCallSystemMessageAdapter
        self.notificationPresenterWrapper = notificationPresenterWrapper
        self.groupCallParticipantInfoFetcher = groupCallParticipantInfoFetcher
        self.groupCallSessionHelper = groupCallSessionHelper
        self.groupCallBundleUtil = groupCallBundleUtil
        self.isRunningForScreenshots = isRunningForScreenshots
        self.audioSessionManager = audioSessionManager
    }
}
