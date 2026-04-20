import Foundation

/// Static Configuration
public enum GroupCallConfiguration {
    enum ProtocolDefines {
        static let protocolVersion: UInt32 = 1
        static let startMessageReceiveTimeout = 60 * 60 * 24 * 14
    }

    enum SubscribeVideo {
        static let fps: UInt32 = 30
        static let width: UInt32 = 720
        static let height: UInt32 = 720
    }
    
    enum SendVideo {
        static let fps: Int32 = 30
        static let width: Int32 = 720
        static let height: Int32 = 720
    }
    
    public enum ActiveCallSwitching {
        public static let delayBeforeReplacingCallInMs = 500
    }
    
    public enum LocalInitialMuteState {
        static let video = OwnMuteState.muted
        static let audio = OwnMuteState.muted
    }
}
