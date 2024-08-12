//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

extension UIColor {
    
    public enum IDColor {
        // The mapping is in the order they are listed here
    
        /// Please don't access this directly except for testing & debugging
        static var deepOrange = UIColor { _ in
            Asset.SharedColors.idColorDeepOrange.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var orange = UIColor { _ in
            Asset.SharedColors.idColorOrange.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var amber = UIColor { _ in
            Asset.SharedColors.idColorAmber.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var yellow = UIColor { _ in
            Asset.SharedColors.idColorYellow.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var olive = UIColor { _ in
            Asset.SharedColors.idColorOlive.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var lightGreen = UIColor { _ in
            Asset.SharedColors.idColorLightGreen.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var green = UIColor { _ in
            Asset.SharedColors.idColorGreen.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var teal = UIColor { _ in
            Asset.SharedColors.idColorTeal.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var cyan = UIColor { _ in
            Asset.SharedColors.idColorCyan.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var lightBlue = UIColor { _ in
            Asset.SharedColors.idColorLightBlue.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var blue = UIColor { _ in
            Asset.SharedColors.idColorBlue.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var indigo = UIColor { _ in
            Asset.SharedColors.idColorIndigo.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var deepPurple = UIColor { _ in
            Asset.SharedColors.idColorDeepPurple.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var purple = UIColor { _ in
            Asset.SharedColors.idColorPurple.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var pink = UIColor { _ in
            Asset.SharedColors.idColorPink.color
        }
    
        /// Please don't access this directly except for testing & debugging
        static var red = UIColor { _ in
            Asset.SharedColors.idColorRed.color
        }
    
        /// Only use for debugging: All ID colors in defined order
        public static let debugColors = [
            deepOrange,
            orange,
            amber,
            yellow,
            olive,
            lightGreen,
            green,
            teal,
            cyan,
            lightBlue,
            blue,
            indigo,
            deepPurple,
            purple,
            pink,
            red,
        ]
    
        /// Dynamic ID Color color for the passed byte
        /// - Parameter byte: Byte to get color for
        /// - Returns: Dynamic color for the passed byte
        static func forByte(_ byte: UInt8) -> UIColor {
            switch byte {
            case 0x00...0x0F:
                deepOrange
            case 0x10...0x1F:
                orange
            case 0x20...0x2F:
                amber
            case 0x30...0x3F:
                yellow
            case 0x40...0x4F:
                olive
            case 0x50...0x5F:
                lightGreen
            case 0x60...0x6F:
                green
            case 0x70...0x7F:
                teal
            case 0x80...0x8F:
                cyan
            case 0x90...0x9F:
                lightBlue
            case 0xA0...0xAF:
                blue
            case 0xB0...0xBF:
                indigo
            case 0xC0...0xCF:
                deepPurple
            case 0xD0...0xDF:
                purple
            case 0xE0...0xEF:
                pink
            case 0xF0...0xFF:
                red
            default:
                fatalError("This is out of range for 8 bits and should never be reached")
            }
        }
    }
}
