//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

/// Use this class to get your URL to threema.ch or threema.ch/work
public enum ThreemaURLProvider {
    
    private static let defaultConsumerURLString = "https://threema.ch/"
    private static let defaultWorkURLString = "https://threema.ch/work/"
    
    // Consumer
    public static let consumerWebsite = URL(string: defaultConsumerURLString)!
    public static let rogueDeviceInfo =
        URL(string: defaultConsumerURLString + "/faq/another_connection")!
    public static let resetSafePassword = URL(string: defaultConsumerURLString + "faq/safepw")!
    public static let consumerDownload = URL(string: defaultConsumerURLString + "download")!
    public static let privacyPolicy = URL(string: defaultConsumerURLString + "privacy_policy")!
    public static let termsOfService = URL(string: defaultConsumerURLString + "tos")!
    public static let multiDeviceReset = URL(string: defaultConsumerURLString + "faq/md_reset")!
    public static let multiDeviceLimit = URL(string: defaultConsumerURLString + "faq/md_limit")!
    public static let iOSBackupManualEN =
        URL(string: defaultConsumerURLString + "docs/threema/ios_backup_manual_en.pdf")!
    public static let safeWebdav = URL(string: defaultConsumerURLString + "faq/threema_safe_webdav")!
    public static let enterLicenseWorkInfo = URL(string: defaultConsumerURLString + "work?li=in-app-work")!
    
    // Work
    public static let workDownload = URL(string: defaultWorkURLString + "download")!
    public static let workInfo = URL(string: defaultConsumerURLString + "work_info")!
}

/// Use this class to get your URL to threema.ch or threema.ch/work
///
/// - returns: URL
@available(*, deprecated, message: "Only use from Objective-C", renamed: "conversationStore")
@objc public class ThreemaURLProviderObjc: NSObject {
    @objc public enum ThreemaURLProviderType: Int, RawRepresentable {
        case consumerWebsite
        case rogueDeviceInfo
        case multiDeviceReset
    }
    
    @objc public class func getURL(_ threemaURLProvider: ThreemaURLProviderType) -> URL {
        switch threemaURLProvider {
        case .consumerWebsite:
            ThreemaURLProvider.consumerWebsite
        case .rogueDeviceInfo:
            ThreemaURLProvider.rogueDeviceInfo
        case .multiDeviceReset:
            ThreemaURLProvider.multiDeviceReset
        }
    }
}
