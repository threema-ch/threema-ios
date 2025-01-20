//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

final class UIColorTests: XCTestCase {
    
    func test00DeepOrange() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(UInt8.min), UIColor.IDColor.deepOrange)
        XCTAssertEqual(UIColor.IDColor.forByte(0x00), UIColor.IDColor.deepOrange)
        XCTAssertEqual(UIColor.IDColor.forByte(0x05), UIColor.IDColor.deepOrange)
        XCTAssertEqual(UIColor.IDColor.forByte(0x0F), UIColor.IDColor.deepOrange)
    }
    
    func test01Orange() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0x10), UIColor.IDColor.orange)
        XCTAssertEqual(UIColor.IDColor.forByte(0x11), UIColor.IDColor.orange)
        XCTAssertEqual(UIColor.IDColor.forByte(0x1F), UIColor.IDColor.orange)
    }
    
    func test02Amber() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0x20), UIColor.IDColor.amber)
        XCTAssertEqual(UIColor.IDColor.forByte(0x28), UIColor.IDColor.amber)
        XCTAssertEqual(UIColor.IDColor.forByte(0x2F), UIColor.IDColor.amber)
    }
    
    func test03Yellow() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0x30), UIColor.IDColor.yellow)
        XCTAssertEqual(UIColor.IDColor.forByte(0x3B), UIColor.IDColor.yellow)
        XCTAssertEqual(UIColor.IDColor.forByte(0x3F), UIColor.IDColor.yellow)
    }
    
    func test04Olive() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0x40), UIColor.IDColor.olive)
        XCTAssertEqual(UIColor.IDColor.forByte(0x4D), UIColor.IDColor.olive)
        XCTAssertEqual(UIColor.IDColor.forByte(0x4F), UIColor.IDColor.olive)
    }
    
    func test05LightGreen() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0x50), UIColor.IDColor.lightGreen)
        XCTAssertEqual(UIColor.IDColor.forByte(0x52), UIColor.IDColor.lightGreen)
        XCTAssertEqual(UIColor.IDColor.forByte(0x5F), UIColor.IDColor.lightGreen)
    }
    
    func test06Green() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0x60), UIColor.IDColor.green)
        XCTAssertEqual(UIColor.IDColor.forByte(0x63), UIColor.IDColor.green)
        XCTAssertEqual(UIColor.IDColor.forByte(0x6F), UIColor.IDColor.green)
    }
    
    func test07Teal() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0x70), UIColor.IDColor.teal)
        XCTAssertEqual(UIColor.IDColor.forByte(0x79), UIColor.IDColor.teal)
        XCTAssertEqual(UIColor.IDColor.forByte(0x7F), UIColor.IDColor.teal)
    }
    
    func test08Cyan() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0x80), UIColor.IDColor.cyan)
        XCTAssertEqual(UIColor.IDColor.forByte(0x8A), UIColor.IDColor.cyan)
        XCTAssertEqual(UIColor.IDColor.forByte(0x8F), UIColor.IDColor.cyan)
    }
    
    func test09LightBlue() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0x90), UIColor.IDColor.lightBlue)
        XCTAssertEqual(UIColor.IDColor.forByte(0x94), UIColor.IDColor.lightBlue)
        XCTAssertEqual(UIColor.IDColor.forByte(0x9F), UIColor.IDColor.lightBlue)
    }
    
    func test10Blue() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0xA0), UIColor.IDColor.blue)
        XCTAssertEqual(UIColor.IDColor.forByte(0xAE), UIColor.IDColor.blue)
        XCTAssertEqual(UIColor.IDColor.forByte(0xAF), UIColor.IDColor.blue)
    }
    
    func test11Indigo() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0xB0), UIColor.IDColor.indigo)
        XCTAssertEqual(UIColor.IDColor.forByte(0xBB), UIColor.IDColor.indigo)
        XCTAssertEqual(UIColor.IDColor.forByte(0xBF), UIColor.IDColor.indigo)
    }
    
    func test12DeepPurple() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0xC0), UIColor.IDColor.deepPurple)
        XCTAssertEqual(UIColor.IDColor.forByte(0xCC), UIColor.IDColor.deepPurple)
        XCTAssertEqual(UIColor.IDColor.forByte(0xCF), UIColor.IDColor.deepPurple)
    }
    
    func test13Purple() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0xD0), UIColor.IDColor.purple)
        XCTAssertEqual(UIColor.IDColor.forByte(0xD6), UIColor.IDColor.purple)
        XCTAssertEqual(UIColor.IDColor.forByte(0xDF), UIColor.IDColor.purple)
    }
    
    func test14Pink() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0xE0), UIColor.IDColor.pink)
        XCTAssertEqual(UIColor.IDColor.forByte(0xE7), UIColor.IDColor.pink)
        XCTAssertEqual(UIColor.IDColor.forByte(0xEF), UIColor.IDColor.pink)
    }
    
    func test15Red() throws {
        XCTAssertEqual(UIColor.IDColor.forByte(0xF0), UIColor.IDColor.red)
        XCTAssertEqual(UIColor.IDColor.forByte(0xFA), UIColor.IDColor.red)
        XCTAssertEqual(UIColor.IDColor.forByte(0xFF), UIColor.IDColor.red)
        XCTAssertEqual(UIColor.IDColor.forByte(UInt8.max), UIColor.IDColor.red)
    }
}
