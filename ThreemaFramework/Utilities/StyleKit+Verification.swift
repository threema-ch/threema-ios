//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

extension StyleKit {
    public static func verificationImage(for level: Int) -> UIImage {
        switch level {
        case 0:
            StyleKit.verification0
        case 1:
            StyleKit.verification1
        case 2:
            StyleKit.verification2
        case 3:
            StyleKit.verification3
        case 4:
            StyleKit.verification4
        default:
            fatalError("Unknown verification level \(level)")
        }
    }
    
    public static func verificationImageBig(for level: Int) -> UIImage {
        switch level {
        case 0:
            StyleKit.verificationBig0
        case 1:
            StyleKit.verificationBig1
        case 2:
            StyleKit.verificationBig2
        case 3:
            StyleKit.verificationBig3
        case 4:
            StyleKit.verificationBig4
        default:
            fatalError("Unknown verification level \(level)")
        }
    }
}
