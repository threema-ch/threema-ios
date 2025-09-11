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

/// Use this class to get your URL to threema.com or threema.com/work
public enum ThreemaURLProvider {
    
    private static let defaultURLString = "https://threema.com/"
    
    // Consumer
    public static let rogueDeviceInfo =
        URL(string: defaultURLString + "/faq/another_connection")!
    public static let resetSafePassword = URL(string: defaultURLString + "faq/safepw")!
    public static let consumerDownload = URL(string: defaultURLString + "download")!
    public static let privacyPolicy = URL(string: defaultURLString + "privacy_policy")!
    public static let termsOfService = URL(string: defaultURLString + "tos")!
    public static let multiDeviceReset = URL(string: defaultURLString + "faq/md_reset")!
    public static let multiDeviceLimit = URL(string: defaultURLString + "faq/md_limit")!
    public static let iOSBackupManualEN =
        URL(string: defaultURLString + "docs/threema/ios_backup_manual_en.pdf")!
    public static let safeWebdav = URL(string: defaultURLString + "faq/threema_safe_webdav")!
    public static let flavorInfoWork =
        URL(string: defaultURLString + "products/work?mtm_campaign=introduction-work-promo&mtm_kwd=ios")
    public static let flavorInfoOnPrem =
        URL(string: defaultURLString + "products/onprem?mtm_campaign=introduction-onprem-promo&mtm_kwd=ios")
    public static let backupFAQ = URL(string: defaultURLString + "faq/backup-options")!
    public static let notificationTypesFAQ = URL(string: defaultURLString + "faq/ios-notification-types")!
    public static let interactionFAQ = URL(string: defaultURLString + "faq/ios-interactions")!
        
    // Work
    public static let workDownload = URL(string: defaultURLString + "/work/download")!
    public static let workInfo = URL(string: defaultURLString + "work_info")!
    public static let privateDownloadAppStore: URL? = URL(string: "itms-apps://itunes.apple.com/app/id578665578")
       
    private static let supportFAQURL = URL(string: defaultURLString + "ios/support")!
    private static let deviceJoinDownloadPrivateString = "https://three.ma/md"
    private static let deviceJoinDownloadWorkString = "https://three.ma/mdw"
    private static let deviceJoinDownloadOnPremString = "https://three.ma/mdo"
    
    public static let supportFAQ = {
        switch TargetManager.current {
        case .threema, .green:
            return supportFAQURL
            
        case .work, .blue, .onPrem:
            guard let licenseURL = BusinessInjector.ui.myIdentityStore.licenseSupportURL,
                  let url = URL(string: licenseURL),
                  !licenseURL.isEmpty else {
                return supportFAQURL
            }
            
            return url
            
        case .customOnPrem:
            if let presetSupportFAQ = BundleUtil.object(forInfoDictionaryKey: "SupportFAQURL") as? String,
               !presetSupportFAQ.isEmpty,
               let presetSupportFAQURL = URL(string: presetSupportFAQ) {
                return presetSupportFAQURL
            }
            
            guard let licenseURL = BusinessInjector.ui.myIdentityStore.licenseSupportURL,
                  let url = URL(string: licenseURL),
                  !licenseURL.isEmpty else {
                return supportFAQURL
            }
            
            return url
        }
    }
    
    public static let deviceJoinDownloadString = {
        switch TargetManager.current {
        case .threema, .green:
            return deviceJoinDownloadPrivateString
        case .work, .blue:
            return deviceJoinDownloadWorkString
        case .onPrem:
            return deviceJoinDownloadOnPremString
        case .customOnPrem:
            guard let predefinedDeviceJoinDownloadString = BundleUtil
                .object(forInfoDictionaryKey: "DeviceJoinDownloadURL") as? String,
                !predefinedDeviceJoinDownloadString.isEmpty else {
                return deviceJoinDownloadOnPremString
            }
            
            return predefinedDeviceJoinDownloadString
        }
    }
}

/// Use this class to get your URL to threema.com or threema.com/work
///
/// - returns: URL
@available(*, deprecated, message: "Only use from Objective-C", renamed: "conversationStore")
@objc public class ThreemaURLProviderObjc: NSObject {
    @objc public enum ThreemaURLProviderType: Int, RawRepresentable {
        case rogueDeviceInfo
        case multiDeviceReset
        case privacyPolicy
    }
    
    @objc public class func getURL(_ threemaURLProvider: ThreemaURLProviderType) -> URL {
        switch threemaURLProvider {
        case .rogueDeviceInfo:
            ThreemaURLProvider.rogueDeviceInfo
        case .multiDeviceReset:
            ThreemaURLProvider.multiDeviceReset
        case .privacyPolicy:
            ThreemaURLProvider.privacyPolicy
        }
    }
}
