import Foundation
@testable import GroupCalls

final class MockDependencies {
    var mockHTTPClient: MockHTTPClient?
    var mockHTTHelper = MockHTTPHelper()
    var mockGroupCallCrypto = MockGroupCallCrypto()
    var mockGroupCallDateFormatter = MockGroupCallDateFormatter()
    var mockUserSettings = MockGroupCallUserSettings(ipv6Enabled: true, disableProximityMonitoring: false)
    var mockGroupCallSystemMessageAdapter = MockGroupCallSystemMessageAdapter()
    var mockNotificationPresenterWrapper = MockNotificationPresenterWrapper()
    var mockGroupCallParticipantInfoFetcher = MockGroupCallParticipantInfoFetcher()
    var mockGroupCallSessionHelper = MockGroupCallSessionHelper()
    var mockGroupCallBundleUtil = MockGroupCallBundleUtil()
    
    func with(_ mockHTTPlient: MockHTTPClient) -> MockDependencies {
        mockHTTPClient = mockHTTPlient
        
        return self
    }
    
    func create() -> Dependencies {
        Dependencies(
            groupCallsHTTPClientAdapter: mockHTTPClient ?? MockHTTPClient(),
            httpHelper: mockHTTHelper,
            groupCallCrypto: mockGroupCallCrypto,
            groupCallDateFormatter: mockGroupCallDateFormatter,
            userSettings: mockUserSettings,
            groupCallSystemMessageAdapter: mockGroupCallSystemMessageAdapter,
            notificationPresenterWrapper: mockNotificationPresenterWrapper,
            groupCallParticipantInfoFetcher: mockGroupCallParticipantInfoFetcher,
            groupCallSessionHelper: mockGroupCallSessionHelper,
            groupCallBundleUtil: mockGroupCallBundleUtil,
            isRunningForScreenshots: false
        )
    }
}
