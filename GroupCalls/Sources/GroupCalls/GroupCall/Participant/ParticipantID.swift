//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

struct ParticipantID: Sendable {
    var id: UInt32 {
        didSet {
            if id >= MIDS_MAX {
                fatalError("Not a valid participant id: \(id)")
            }
        }
    }
}

// MARK: - Equatable

extension ParticipantID: Equatable {
    static func == (lhs: ParticipantID, rhs: ParticipantID) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension ParticipantID: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
