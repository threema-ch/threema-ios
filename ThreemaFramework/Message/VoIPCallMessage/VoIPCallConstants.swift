//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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

@objc class VoIPCallConstants: NSObject {
    @objc static let JSON_OFFER_OFFER = "offer"
    
    @objc static let JSON_FEATURES = "features"
    @objc static let JSON_FEATURES_VIDEO = "video"
    
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
