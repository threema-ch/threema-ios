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

import CocoaLumberjackSwift
import Foundation
import WebRTC

private let MIDS = SDP_TOKEN_RANGE + SDP_TOKEN_RANGE.flatMap { first in
    SDP_TOKEN_RANGE.map { second in
        "\(first)\(second)"
    }
}

private let MIDS_PER_PARTICIPANT = 8

let MIDS_MAX = MIDS.count / MIDS_PER_PARTICIPANT

typealias Mid = String

struct Mids {
    var microphone: Mid
    var camera: Mid
    var r1: Mid
    var r2: Mid
    var r3: Mid
    var r4: Mid
    var r5: Mid
    var data: Mid
    
    init(from participantID: ParticipantID) {
        let offset = Int(participantID.id) * MIDS_PER_PARTICIPANT
        
        self.microphone = MIDS[offset + 0]
        self.camera = MIDS[offset + 1]
        self.r1 = MIDS[offset + 2]
        self.r2 = MIDS[offset + 3]
        self.r3 = MIDS[offset + 4]
        self.r4 = MIDS[offset + 5]
        self.r5 = MIDS[offset + 6]
        self.data = MIDS[offset + 7]
    }
    
    func toMap() -> [SdpKind: String] {
        [
            .audio: microphone,
            .video: camera,
        ]
    }
}

private let SDP_TOKEN_RANGE = [
    "!", // Participant 0 mic
    "#", // Participant 0 vid
    "$",
    "%",
    "&",
    "'",
    "*",
    "+",
    "-", // Participant 1 mic
    ".", // Participant 1 vid
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9",
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
    "^",
    "_",
    "`",
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z",
    "{",
    "|",
    "}",
    "~",
]
