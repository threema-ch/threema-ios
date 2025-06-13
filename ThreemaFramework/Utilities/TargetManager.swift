//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

public enum TargetManager {
    case threema
    case work
    case green
    case blue
    case onPrem
    case customOnPrem
    
    public static let current: TargetManager = {
        guard !ProcessInfoHelper.isRunningForTests else {
            return .threema
        }
        
        switch BundleUtil.targetManagerKey() {
        case "Threema":
            return .threema
        case "ThreemaGreen":
            return .green
        case "ThreemaWork":
            return .work
        case "ThreemaBlue":
            return .blue
        case "ThreemaOnPrem":
            return .onPrem
        case "CustomOnPrem":
            return .customOnPrem
        case let .some(bundleName):
            fatalError("There is a unknown bundle id \(bundleName)")
        case .none:
            return handleNoneTargetManager()
        }
    }()
    
    /// Verify the appropriate course of action in the event that the targetManagerKey is not set.
    /// - Returns: TargetManager
    private static func handleNoneTargetManager() -> TargetManager {
        guard ProcessInfoHelper.isRunningForScreenshots else {
            fatalError("There is no bundle id")
        }
        switch ProcessInfoHelper.targetManagerKeyForScreenshots {
        case "Threema":
            return .threema
        case "ThreemaWork":
            return .work
        case "ThreemaOnPrem":
            return .onPrem
        default:
            fatalError("There is no target manager key for screenshots")
        }
    }
    
    /// Returns the CFBundleName for the current process. E.g. `ThreemaShareExtension` for the share extension or
    /// `Threema` for the app.
    /// See `appName`
    public static let targetName: String = Bundle.main
        .object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Threema"
    
    /// Returns the CFBundleName for the app to which the current process belongs. E.g. if we are running in the
    /// ThreemaShareExtension this will return `Threema`.
    /// See `currentName`
    public static let appName: String = BundleUtil.mainBundle()?
        .object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Threema"
    
    /// Returns the localized app name to be used before ID or Call
    /// For example for Threema Work or Threema OnPrem this would be equal to Threema
    public static let localizedAppName: String = {
        guard let string = BundleUtil.object(forInfoDictionaryKey: "LocalizedAppName") as? String else {
            return "Threema"
        }
        
        return string
    }()
    
    /// Link to open for writing an AppStore review
    public static let rateLink: URL? = {
        guard let string = BundleUtil.object(forInfoDictionaryKey: "ThreemaRateLink") as? String,
              let url = URL(string: string) else {
            return nil
        }
        
        return url
    }()
    
    public static let isSandbox =
        switch current {
        case .green, .blue:
            true
        case .threema, .work, .onPrem, .customOnPrem:
            false
        }
    
    public static let isBusinessApp =
        switch current {
        case .work, .blue, .onPrem, .customOnPrem:
            true
        case .threema, .green:
            false
        }
    
    public static let isWork =
        switch current {
        case .work, .blue:
            true
        case .threema, .green, .onPrem, .customOnPrem:
            false
        }
    
    public static let isOnPrem =
        switch current {
        case .onPrem, .customOnPrem:
            true
        case .threema, .green, .work, .blue:
            false
        }
    
    public static let isCustomOnPrem = current == .customOnPrem
}

@objc public class TargetManagerObjc: NSObject {
    
    @objc public enum TargetManager: Int, RawRepresentable {
        case threema
        case work
        case green
        case blue
        case onPrem
        case customOnPrem
    }
    
    @objc public static let current: TargetManager = {
        guard !ProcessInfoHelper.isRunningForTests else {
            return .threema
        }
        
        switch BundleUtil.targetManagerKey() {
        case "Threema":
            return .threema
        case "ThreemaGreen":
            return .green
        case "ThreemaWork":
            return .work
        case "ThreemaBlue":
            return .blue
        case "ThreemaOnPrem":
            return .onPrem
        case "CustomOnPrem":
            return .customOnPrem
        case let .some(key):
            fatalError("There is a unknown target manager key \(key)")
        case .none:
            return handleNoneTargetManager()
        }
    }()
    
    /// Verify the appropriate course of action in the event that the targetManagerKey is not set.
    /// - Returns: TargetManager
    private static func handleNoneTargetManager() -> TargetManager {
        guard ProcessInfoHelper.isRunningForScreenshots else {
            fatalError("There is no bundle id")
        }
        switch ProcessInfoHelper.targetManagerKeyForScreenshots {
        case "Threema":
            return .threema
        case "ThreemaWork":
            return .work
        case "ThreemaOnPrem":
            return .onPrem
        default:
            fatalError("There is no target manager key for screenshots")
        }
    }
    
    @objc public static let targetName: String = Bundle.main
        .object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Threema"
    
    @objc public static let appName: String = BundleUtil.mainBundle()?
        .object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Threema"
    
    /// Returns the localized app name to be used before ID or Call
    /// For example for Threema Work or Threema OnPrem this would be equal to Threema
    @objc public static let localizedAppName: String = {
        guard let string = BundleUtil.object(forInfoDictionaryKey: "LocalizedAppName") as? String else {
            return "Threema"
        }
        
        return string
    }()
    
    @objc public static let isSandbox =
        switch current {
        case .green, .blue:
            true
        case .threema, .work, .onPrem, .customOnPrem:
            false
        }
    
    @objc static let isBusinessApp =
        switch current {
        case .work, .blue, .onPrem, .customOnPrem:
            true
        case .threema, .green:
            false
        }
    
    @objc static let isWork =
        switch current {
        case .work, .blue:
            true
        case .threema, .green, .onPrem, .customOnPrem:
            false
        }
    
    @objc static let isOnPrem =
        switch current {
        case .onPrem, .customOnPrem:
            true
        case .threema, .green, .work, .blue:
            false
        }
    
    @objc static let isCustomOnPrem = current == .customOnPrem
}
