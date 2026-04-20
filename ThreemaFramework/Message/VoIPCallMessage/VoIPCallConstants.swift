import Foundation

class VoIPCallConstants: NSObject {
    static let JSON_OFFER_OFFER = "offer"
    
    static let JSON_FEATURES = "features"
    static let JSON_FEATURES_VIDEO = "video"
    
    static let JSON_OFFER_OFFER_SDPTYPE = "sdpType"
    static let JSON_OFFER_OFFER_SDP = "sdp"
    
    static let JSON_ANSWER_ACTION = "action"
    static let JSON_ANSWER_ANSWER = "answer"
    static let JSON_ANSWER_ANSWER_SDPTYPE = "sdpType"
    static let JSON_ANSWER_ANSWER_SDP = "sdp"
    static let JSON_ANSWER_REJECTREASON = "rejectReason"
    
    static let JSON_ICE_CANDIDATE_REMOVED = "removed"
    static let JSON_ICE_CANDIDATE_CANDIDATES = "candidates"
    
    static let callIDKey = "callId"
}
