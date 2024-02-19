//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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
import Reachability
import ThreemaProtocols

public enum CallsignalingProtocol {
    
    static let minBitrate: UInt32 = 200
    static let minResolutionWidth: CGFloat = 320
    static let minResolutionHeight: CGFloat = 240
    static let minFps: UInt32 = 15
    
    // MARK: Objects
    
    public struct ThreemaVideoCallSignalingMessage {
        public var videoQualityProfile: ThreemaVideoCallQualityProfile?
        public var captureStateChange: ThreemaVideoCallCaputreState?
    }
    
    public struct ThreemaVideoCallQualityProfile {
        public var bitrate: UInt32
        public var maxResolution: CGSize
        public var maxFps: UInt32
        public var profile: ThreemaVideoCallQualityProfiles?
        
        public func debug() -> String {
            let width = String(format: "%.0f", maxResolution.width)
            let height = String(format: "%.0f", maxResolution.height)
            return "profile=\(profile?.debug() ?? "n/a"), \(bitrate)kps, \(maxFps)fps, \(width)x\(height)"
        }
    }
    
    public enum ThreemaVideoCallQualityProfiles: Int {
        case max
        case high
        case low
        
        public func qualityProfile() -> ThreemaVideoCallQualityProfile {
            switch self {
            case .max:
                return ThreemaVideoCallQualityProfile(
                    bitrate: 4000,
                    maxResolution: CGSize(width: 1920, height: 1080),
                    maxFps: 25,
                    profile: .max
                )
            case .high:
                return ThreemaVideoCallQualityProfile(
                    bitrate: 2000,
                    maxResolution: CGSize(width: 1280, height: 720),
                    maxFps: 25,
                    profile: .high
                )
            case .low:
                return ThreemaVideoCallQualityProfile(
                    bitrate: 400,
                    maxResolution: CGSize(width: 960, height: 540),
                    maxFps: 20,
                    profile: .low
                )
            }
        }
        
        public func debug() -> String {
            switch self {
            case .max:
                return "MAX"
            case .high:
                return "HIGH"
            case .low:
                return "LOW"
            }
        }
    }
    
    public struct ThreemaVideoCallCaputreState {
        public var device: ThreemaVideoCallCaputreDevice
        public var state: ThreemaVideoCallMode
    }
        
    public enum ThreemaVideoCallCaputreDevice: Int {
        case camera
        case screenSharing
        case microphone
    }
    
    public enum ThreemaVideoCallMode: Int {
        case off
        case on
    }
}

extension CallsignalingProtocol {
    
    // MARK: Encode / Decode
    
    public static func encodeMute(_ isMicrophoneMuted: Bool) -> Data? {
        var envelop = Callsignaling_Envelope()
        var captureState = Callsignaling_CaptureState()
        captureState.device = .microphone
        captureState.state = isMicrophoneMuted ? .off : .on
        envelop.captureStateChange = captureState
        return try? envelop.serializedData()
    }
    
    public static func encodeVideoCapture(_ isCapture: Bool) -> Data? {
        var envelop = Callsignaling_Envelope()
        var captureState = Callsignaling_CaptureState()
        captureState.device = .camera
        captureState.state = isCapture ? .on : .off
        envelop.captureStateChange = captureState
        return try? envelop.serializedData()
    }
    
    public static func encodeVideoQuality(_ profile: ThreemaVideoCallQualityProfiles) -> Data? {
        let threemaVideoCallQualityProfile = profile.qualityProfile()
        var envelop = Callsignaling_Envelope()
        var videoQualityProfile = Callsignaling_VideoQualityProfile()
        
        videoQualityProfile.profile = Callsignaling_VideoQualityProfile
            .QualityProfile(rawValue: threemaVideoCallQualityProfile.profile!.rawValue)!
        videoQualityProfile.maxBitrateKbps = threemaVideoCallQualityProfile.bitrate
        videoQualityProfile.maxFps = threemaVideoCallQualityProfile.maxFps
        
        var resolution = Common_Resolution()
        resolution.width = UInt32(threemaVideoCallQualityProfile.maxResolution.width)
        resolution.height = UInt32(threemaVideoCallQualityProfile.maxResolution.height)
        videoQualityProfile.maxResolution = resolution
        
        envelop.videoQualityProfile = videoQualityProfile
        return try? envelop.serializedData()
    }
    
    public static func decodeThreemaVideoCallSignalingMessage(_ data: Data) -> ThreemaVideoCallSignalingMessage {
        var threemaVideoCallQualityProfile: ThreemaVideoCallQualityProfile?
        var threemaVideoCallCaputreState: ThreemaVideoCallCaputreState?
        
        let envelop = try? Callsignaling_Envelope(serializedData: data)
                
        switch envelop?.content {
        case .captureStateChange(envelop?.captureStateChange):
            threemaVideoCallCaputreState = ThreemaVideoCallCaputreState(
                device: ThreemaVideoCallCaputreDevice(rawValue: envelop!.captureStateChange.device.rawValue)!,
                state: ThreemaVideoCallMode(rawValue: envelop!.captureStateChange.state.rawValue)!
            )
        case .videoQualityProfile(envelop?.videoQualityProfile):
            threemaVideoCallQualityProfile = ThreemaVideoCallQualityProfile(
                bitrate: envelop!.videoQualityProfile.maxBitrateKbps,
                maxResolution: CGSize(
                    width: Int(envelop!.videoQualityProfile.maxResolution.width),
                    height: Int(envelop!.videoQualityProfile.maxResolution.height)
                ),
                maxFps: envelop!.videoQualityProfile.maxFps,
                profile: ThreemaVideoCallQualityProfiles(rawValue: envelop!.videoQualityProfile.profile.rawValue)!
            )
        default: break
        }
        
        return ThreemaVideoCallSignalingMessage(
            videoQualityProfile: threemaVideoCallQualityProfile,
            captureStateChange: threemaVideoCallCaputreState
        )
    }
}

extension CallsignalingProtocol {
    
    // MARK: Public static functions
    
    public static func currentThreemaVideoCallQualitySettingTitle() -> String {
        threemaVideoCallQualitySettingTitle(for: UserSettings.shared().threemaVideoCallQualitySetting)
    }
    
    public static func threemaVideoCallQualitySettingTitle(for setting: ThreemaVideoCallQualitySetting) -> String {
        switch setting {
        case ThreemaVideoCallQualitySettingAuto:
            return BundleUtil.localizedString(forKey: "settings_threema_calls_video_quality_profile_auto")
        case ThreemaVideoCallQualitySettingMaximumQuality:
            return BundleUtil.localizedString(forKey: "settings_threema_calls_video_quality_profile_max")
        case ThreemaVideoCallQualitySettingLowDataConsumption:
            return BundleUtil.localizedString(forKey: "settings_threema_calls_video_quality_profile_low")
        default:
            return "Unknown"
        }
    }
    
    public static func threemaVideoCallQualitySettingSubtitle(for setting: ThreemaVideoCallQualitySetting) -> String {
        switch setting {
        case ThreemaVideoCallQualitySettingAuto:
            return BundleUtil.localizedString(forKey: "settings_threema_calls_video_quality_profile_auto_description")
        case ThreemaVideoCallQualitySettingMaximumQuality:
            return BundleUtil.localizedString(forKey: "settings_threema_calls_video_quality_profile_max_description")
        case ThreemaVideoCallQualitySettingLowDataConsumption:
            return BundleUtil.localizedString(forKey: "settings_threema_calls_video_quality_profile_low_description")
        default:
            return "Unknown"
        }
    }
    
    public static func threemaVideoCallQualitySettingCount() -> Int {
        3
    }
    
    public static func isThreemaVideoCallQualitySettingAuto() -> Bool {
        UserSettings.shared()?.threemaVideoCallQualitySetting == ThreemaVideoCallQualitySettingAuto
    }
    
    public static func threemaVideoCallQualitySettingSelected(for setting: ThreemaVideoCallQualitySetting) -> Bool {
        UserSettings.shared()?.threemaVideoCallQualitySetting == setting
    }
    
    public static func localCaptureQualityProfile() -> ThreemaVideoCallQualityProfile {
        if UserSettings.shared()?.threemaVideoCallQualitySetting == ThreemaVideoCallQualitySettingMaximumQuality {
            return ThreemaVideoCallQualityProfiles.max.qualityProfile()
        }

        return ThreemaVideoCallQualityProfiles.high.qualityProfile()
    }
    
    public static func localPeerQualityProfile() -> ThreemaVideoCallQualityProfile {
        let reachability = try! Reachability()
        switch UserSettings.shared()?.threemaVideoCallQualitySetting {
        case ThreemaVideoCallQualitySettingAuto:
            if reachability.connection == .wifi {
                return ThreemaVideoCallQualityProfiles.high.qualityProfile()
            }
            else {
                return ThreemaVideoCallQualityProfiles.low.qualityProfile()
            }
        case ThreemaVideoCallQualitySettingMaximumQuality:
            return ThreemaVideoCallQualityProfiles.max.qualityProfile()
        case ThreemaVideoCallQualitySettingLowDataConsumption:
            return ThreemaVideoCallQualityProfiles.low.qualityProfile()
        default: break
        }
        return ThreemaVideoCallQualityProfiles.low.qualityProfile()
    }
    
    public static func findCommonProfile(
        remoteProfile: ThreemaVideoCallQualityProfile?,
        networkIsRelayed: Bool,
        _ localProfile: ThreemaVideoCallQualityProfile? = nil
    ) -> ThreemaVideoCallQualityProfile {
        let localQualityProfile = localProfile != nil ? localProfile! : localPeerQualityProfile()
        
        guard remoteProfile != nil else {
            return localQualityProfile
        }
        
        if let foundProfile = remoteProfile?.profile {
            if foundProfile == .low || localQualityProfile.profile == .low {
                return ThreemaVideoCallQualityProfiles.low.qualityProfile()
            }
            else if foundProfile == .high || localQualityProfile.profile == .high {
                return ThreemaVideoCallQualityProfiles.high.qualityProfile()
            }
            else if foundProfile == .max || localQualityProfile.profile == .max {
                return networkIsRelayed ? ThreemaVideoCallQualityProfiles.high
                    .qualityProfile() : ThreemaVideoCallQualityProfiles.max.qualityProfile()
            }
        }
        
        // Unknown profile
        let maxBitrateKbps = max(min(localQualityProfile.bitrate, remoteProfile!.bitrate), minBitrate)
        let maxResolutionWidth = max(
            min(localQualityProfile.maxResolution.width, remoteProfile!.maxResolution.width),
            minResolutionWidth
        )
        let maxResolutionHeight = max(
            min(localQualityProfile.maxResolution.height, remoteProfile!.maxResolution.height),
            minResolutionHeight
        )
        let maxFps = max(min(localQualityProfile.maxFps, remoteProfile!.maxFps), minFps)
        return ThreemaVideoCallQualityProfile(
            bitrate: maxBitrateKbps,
            maxResolution: CGSize(width: maxResolutionWidth, height: maxResolutionHeight),
            maxFps: maxFps,
            profile: remoteProfile!.profile
        )
    }
    
    public static func printDebugQualityProfiles(
        remoteProfile: ThreemaVideoCallQualityProfile?,
        networkIsRelayed: Bool
    ) -> String {
        "\(printLocalQualityProfile())\n\(printPeerQualityProfile(remoteProfile: remoteProfile))\n\(printCommonQualityProfile(remoteProfile: remoteProfile, networkIsRelayed: networkIsRelayed))"
    }
    
    private static func printLocalQualityProfile() -> String {
        let localQualityProfile = localPeerQualityProfile()
        return "L=VoipVideoParams{\(localQualityProfile.debug())}"
    }
    
    private static func printPeerQualityProfile(remoteProfile: ThreemaVideoCallQualityProfile?) -> String {
        guard remoteProfile != nil else {
            return "R=VoipVideoParams{n/a}"
        }
        return "R=VoipVideoParams{\(remoteProfile!.debug())}"
    }
    
    private static func printCommonQualityProfile(
        remoteProfile: ThreemaVideoCallQualityProfile?,
        networkIsRelayed: Bool
    ) -> String {
        let common = findCommonProfile(remoteProfile: remoteProfile, networkIsRelayed: networkIsRelayed)
        return "C=VoipVideoParams{\(common.debug())}"
    }
}
