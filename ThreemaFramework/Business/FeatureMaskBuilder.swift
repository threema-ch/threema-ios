import Foundation
import ThreemaProtocols

class FeatureMaskBuilder {
    private var mask = 0
    
    func audio(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.voiceMessageSupport.rawValue), enabled: enabled)
    }
    
    func group(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.groupSupport.rawValue), enabled: enabled)
    }
    
    func ballot(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.pollSupport.rawValue), enabled: enabled)
    }
    
    func file(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.fileMessageSupport.rawValue), enabled: enabled)
    }
    
    func voip(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.o2OAudioCallSupport.rawValue), enabled: enabled)
    }
    
    func videoCalls(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.o2OVideoCallSupport.rawValue), enabled: enabled)
    }
    
    func forwardSecurity(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.forwardSecuritySupport.rawValue), enabled: enabled)
    }
    
    func groupCalls(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.groupCallSupport.rawValue), enabled: enabled)
    }

    func editMessage(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.editMessageSupport.rawValue), enabled: enabled)
    }
    
    func deleteMessage(enabled: Bool) -> FeatureMaskBuilder {
        set(feature: Int(ThreemaProtocols.Common_CspFeatureMaskFlag.deleteMessageSupport.rawValue), enabled: enabled)
    }
    
    func emojiReactions(enabled: Bool) -> FeatureMaskBuilder {
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

extension FeatureMaskBuilder {
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
