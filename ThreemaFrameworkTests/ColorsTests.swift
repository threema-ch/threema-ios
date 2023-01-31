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

import XCTest
@testable import ThreemaFramework

final class ColorsTests: XCTestCase {
    
    func test00DeepOrange() throws {
        XCTAssertEqual(Colors.IDColor.forByte(UInt8.min), Colors.IDColor.deepOrange)
        XCTAssertEqual(Colors.IDColor.forByte(0x00), Colors.IDColor.deepOrange)
        XCTAssertEqual(Colors.IDColor.forByte(0x05), Colors.IDColor.deepOrange)
        XCTAssertEqual(Colors.IDColor.forByte(0x0F), Colors.IDColor.deepOrange)
    }
    
    func test01Orange() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0x10), Colors.IDColor.orange)
        XCTAssertEqual(Colors.IDColor.forByte(0x11), Colors.IDColor.orange)
        XCTAssertEqual(Colors.IDColor.forByte(0x1F), Colors.IDColor.orange)
    }
    
    func test02Amber() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0x20), Colors.IDColor.amber)
        XCTAssertEqual(Colors.IDColor.forByte(0x28), Colors.IDColor.amber)
        XCTAssertEqual(Colors.IDColor.forByte(0x2F), Colors.IDColor.amber)
    }
    
    func test03Yellow() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0x30), Colors.IDColor.yellow)
        XCTAssertEqual(Colors.IDColor.forByte(0x3B), Colors.IDColor.yellow)
        XCTAssertEqual(Colors.IDColor.forByte(0x3F), Colors.IDColor.yellow)
    }
    
    func test04Olive() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0x40), Colors.IDColor.olive)
        XCTAssertEqual(Colors.IDColor.forByte(0x4D), Colors.IDColor.olive)
        XCTAssertEqual(Colors.IDColor.forByte(0x4F), Colors.IDColor.olive)
    }
    
    func test05LightGreen() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0x50), Colors.IDColor.lightGreen)
        XCTAssertEqual(Colors.IDColor.forByte(0x52), Colors.IDColor.lightGreen)
        XCTAssertEqual(Colors.IDColor.forByte(0x5F), Colors.IDColor.lightGreen)
    }
    
    func test06Green() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0x60), Colors.IDColor.green)
        XCTAssertEqual(Colors.IDColor.forByte(0x63), Colors.IDColor.green)
        XCTAssertEqual(Colors.IDColor.forByte(0x6F), Colors.IDColor.green)
    }
    
    func test07Teal() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0x70), Colors.IDColor.teal)
        XCTAssertEqual(Colors.IDColor.forByte(0x79), Colors.IDColor.teal)
        XCTAssertEqual(Colors.IDColor.forByte(0x7F), Colors.IDColor.teal)
    }
    
    func test08Cyan() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0x80), Colors.IDColor.cyan)
        XCTAssertEqual(Colors.IDColor.forByte(0x8A), Colors.IDColor.cyan)
        XCTAssertEqual(Colors.IDColor.forByte(0x8F), Colors.IDColor.cyan)
    }
    
    func test09LightBlue() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0x90), Colors.IDColor.lightBlue)
        XCTAssertEqual(Colors.IDColor.forByte(0x94), Colors.IDColor.lightBlue)
        XCTAssertEqual(Colors.IDColor.forByte(0x9F), Colors.IDColor.lightBlue)
    }
    
    func test10Blue() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0xA0), Colors.IDColor.blue)
        XCTAssertEqual(Colors.IDColor.forByte(0xAE), Colors.IDColor.blue)
        XCTAssertEqual(Colors.IDColor.forByte(0xAF), Colors.IDColor.blue)
    }
    
    func test11Indigo() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0xB0), Colors.IDColor.indigo)
        XCTAssertEqual(Colors.IDColor.forByte(0xBB), Colors.IDColor.indigo)
        XCTAssertEqual(Colors.IDColor.forByte(0xBF), Colors.IDColor.indigo)
    }
    
    func test12DeepPurple() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0xC0), Colors.IDColor.deepPurple)
        XCTAssertEqual(Colors.IDColor.forByte(0xCC), Colors.IDColor.deepPurple)
        XCTAssertEqual(Colors.IDColor.forByte(0xCF), Colors.IDColor.deepPurple)
    }
    
    func test13Purple() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0xD0), Colors.IDColor.purple)
        XCTAssertEqual(Colors.IDColor.forByte(0xD6), Colors.IDColor.purple)
        XCTAssertEqual(Colors.IDColor.forByte(0xDF), Colors.IDColor.purple)
    }
    
    func test14Pink() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0xE0), Colors.IDColor.pink)
        XCTAssertEqual(Colors.IDColor.forByte(0xE7), Colors.IDColor.pink)
        XCTAssertEqual(Colors.IDColor.forByte(0xEF), Colors.IDColor.pink)
    }
    
    func test15Red() throws {
        XCTAssertEqual(Colors.IDColor.forByte(0xF0), Colors.IDColor.red)
        XCTAssertEqual(Colors.IDColor.forByte(0xFA), Colors.IDColor.red)
        XCTAssertEqual(Colors.IDColor.forByte(0xFF), Colors.IDColor.red)
        XCTAssertEqual(Colors.IDColor.forByte(UInt8.max), Colors.IDColor.red)
    }
}
