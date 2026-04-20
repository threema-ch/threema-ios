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
    
    let groupCallsHTTPClientAdapter: GroupCallHTTPClientAdapterProtocol
    let httpHelper: GroupCallSFUTokenFetchAdapterProtocol
    let groupCallCrypto: GroupCallCryptoProtocol
    let groupCallDateFormatter: GroupCallDateFormatterProtocol
    let userSettings: GroupCallUserSettingsProtocol
    let groupCallSystemMessageAdapter: GroupCallSystemMessageAdapterProtocol
    let notificationPresenterWrapper: NotificationPresenterWrapperProtocol
    let groupCallParticipantInfoFetcher: GroupCallParticipantInfoFetcherProtocol
    let groupCallSessionHelper: GroupCallSessionHelperProtocol
    let groupCallBundleUtil: GroupCallBundleUtilProtocol
    let isRunningForScreenshots: Bool

    // MARK: - Lifecycle
    
    public init(
        groupCallsHTTPClientAdapter: GroupCallHTTPClientAdapterProtocol,
        httpHelper: GroupCallSFUTokenFetchAdapterProtocol,
        groupCallCrypto: GroupCallCryptoProtocol,
        groupCallDateFormatter: GroupCallDateFormatterProtocol,
        userSettings: GroupCallUserSettingsProtocol,
        groupCallSystemMessageAdapter: GroupCallSystemMessageAdapterProtocol,
        notificationPresenterWrapper: NotificationPresenterWrapperProtocol,
        groupCallParticipantInfoFetcher: GroupCallParticipantInfoFetcherProtocol,
        groupCallSessionHelper: GroupCallSessionHelperProtocol,
        groupCallBundleUtil: GroupCallBundleUtilProtocol,
        isRunningForScreenshots: Bool
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
    }
}
