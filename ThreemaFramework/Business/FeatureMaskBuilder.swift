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
import ThreemaProtocols

@objc class FeatureMaskBuilder: NSObject {
    private var mask = 0
    
    @objc func audio(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.voiceMessageSupport.rawValue), enabled: enabled)
    }
    
    @objc func group(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.groupSupport.rawValue), enabled: enabled)
    }
    
    @objc func ballot(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.pollSupport.rawValue), enabled: enabled)
    }
    
    @objc func file(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.fileMessageSupport.rawValue), enabled: enabled)
    }
    
    @objc func voip(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.o2OAudioCallSupport.rawValue), enabled: enabled)
    }
    
    @objc func videoCalls(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.o2OVideoCallSupport.rawValue), enabled: enabled)
    }
    
    @objc func forwardSecurity(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.forwardSecuritySupport.rawValue), enabled: enabled)
    }
    
    @objc func groupCalls(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.groupCallSupport.rawValue), enabled: enabled)
    }

    @objc func editMessage(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.editMessageSupport.rawValue), enabled: enabled)
    }
    
    @objc func deleteMessage(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.deleteMessageSupport.rawValue), enabled: enabled)
    }
    
    @objc func emojiReactions(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.reactionSupport.rawValue), enabled: enabled)
    }
    
    private func set(feature: Int, enabled: Bool) -> FeatureMaskBuilder {
        if enabled {
            mask = mask | feature
        }
        else {
            mask = mask & ~feature
        }
        
        return self
    }
    
    func build() -> Int {
        mask
    }
}

@objc extension FeatureMaskBuilder {
    static func upToVideoCalls() -> FeatureMaskBuilder {
        FeatureMaskBuilder()
            .audio(enabled: true)
            .group(enabled: true)
            .ballot(enabled: true)
            .file(enabled: true)
            .voip(enabled: true)
            .videoCalls(enabled: true)
    }
    
    static func current() -> FeatureMaskBuilder {
        FeatureMaskBuilder()
            .audio(enabled: true)
            .group(enabled: true)
            .ballot(enabled: true)
            .file(enabled: true)
            .voip(enabled: true)
            .videoCalls(enabled: true)
            .forwardSecurity(enabled: ThreemaEnvironment.supportsForwardSecurity)
            .groupCalls(enabled: BusinessInjector().settingsStore.enableThreemaGroupCalls)
            .editMessage(enabled: true)
            .deleteMessage(enabled: true)
            .emojiReactions(enabled: true)
    }
}
