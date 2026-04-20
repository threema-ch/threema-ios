import Foundation

enum SdpKind: Int {
    case audio
    case video
    
    var mediaKind: MediaKind {
        MediaKind(rawValue: rawValue)!
    }
}
