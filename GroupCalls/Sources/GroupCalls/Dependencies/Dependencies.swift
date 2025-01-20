//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
