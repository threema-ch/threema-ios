//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
    
public enum ForwardSecrecyState: CustomStringConvertible {
    case noSession, unsupportedByRemote, L20(DHVersions?), R20(DHVersions?), R24(DHVersions?), RL44(DHVersions?)
    
    public var description: String {
        switch self {
        case .noSession:
            return "No Session"
        case .unsupportedByRemote:
            return "Unsupported by Remote"
        case let .L20(version):
            return "L20, \(version?.description ?? "nil")"
        case let .R20(version):
            return "R20, \(version?.description ?? "nil")"
        case let .R24(version):
            return "R24, \(version?.description ?? "nil")"
        case let .RL44(version):
            return "RL44, \(version?.description ?? "nil")"
        }
    }
}
