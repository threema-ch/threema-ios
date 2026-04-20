import Foundation
import ThreemaMacros
import TipKit

extension TipKitManager {
    
    /// Tip shown when type icon is show for first time
    public struct ThreemaTypeTip: Tip {
        public var title: Text {
            if TargetManager.isBusinessApp {
                Text(TargetManager.appName)
            }
            else {
                Text(String.localizedStringWithFormat(
                    #localize("contact_threema_work_title"),
                    TargetManager.localizedAppName
                ))
            }
        }

        public var message: Text? {
            if TargetManager.isBusinessApp {
                Text(String.localizedStringWithFormat(
                    #localize("contact_threema_info"),
                    TargetManager.appName,
                    TargetManager.localizedAppName
                ))
            }
            else {
                Text(String.localizedStringWithFormat(
                    #localize("contact_threema_work_info"),
                    TargetManager.localizedAppName
                ))
            }
        }

        public var image: Image? {
            Image(uiImage: ThreemaUtility.otherThreemaTypeIcon)
        }

        public init() { }
    }
    
    /// Tip shown for users using TestFlight
    public struct ThreemaBetaFeedbackTip: Tip {
        public var title: Text {
            Text(#localize("testflight_feedback_title"))
        }

        public var message: Text? {
            Text(#localize("testflight_feedback_description"))
        }

        public var image: Image? {
            Image(systemName: "ant.fill")
        }

        public init() { }
    }
    
    /// Tip shown when first receive a reaction
    public struct ThreemaReactionLongPressInfoTip: Tip {
        public var title: Text {
            Text(#localize("emoji_reaction_tipkit_title"))
        }

        public var message: Text? {
            Text(#localize("emoji_reaction_tipkit_description"))
        }

        public var image: Image? {
            Image(systemName: "hand.tap")
        }
        
        public var options: [any Option] {
            MaxDisplayCount(2)
        }
        
        public init() { }
    }

    /// Tip shown when first forwarding a file message with caption
    public struct ThreemaForwardingCaptionInfoTip: Tip {

        // swiftformat:disable:next redundantType
        @Parameter static var isInCorrectScenario: Bool = false

        public var title: Text {
            Text(#localize("forward_message_tip_title"))
        }

        public var message: Text? {
            Text(#localize("forward_message_tip_message"))
        }

        public var rules: [Rule] {
            #Rule(Self.$isInCorrectScenario) { $0 == true }
        }

        public init() { }
    }

    public struct ThreemaNoteGroupCreationTip: Tip {
        
        // swiftformat:disable:next redundantType
        @Parameter public static var isInCorrectScenario: Bool = false
        
        public var title: Text {
            Text(#localize("create_note_group_info_title"))
        }
        
        public var message: Text? {
            Text(#localize("create_note_group_info_text"))
        }
        
        public var rules: [Rule] {
            #Rule(Self.$isInCorrectScenario) { $0 == true }
        }
        
        public init() { /* no-op */ }
    }
}
