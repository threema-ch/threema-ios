//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

import XCTest

@testable import Threema

/// Future improvement: Move the test vectors into their own files
class TextViewKeyboardWorkaroundHandlerTests: XCTestCase {
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
    }
    
    private typealias InputType = (range: NSRange, oldText: NSMutableAttributedString, replacementText: String)
    private typealias OutputType = (range: NSRange, fullText: NSMutableAttributedString, newText: String)
    
    private let helloWord = [
        (
            (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "H"),
            (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "H")
        ),
        (
            (NSMakeRange(1, 0), NSMutableAttributedString(string: "H"), "e"),
            (NSMakeRange(1, 0), NSMutableAttributedString(string: "H"), "e")
        ),
        (
            (NSMakeRange(2, 0), NSMutableAttributedString(string: "He"), "l"),
            (NSMakeRange(2, 0), NSMutableAttributedString(string: "He"), "l")
        ),
        (
            (NSMakeRange(3, 0), NSMutableAttributedString(string: "Hel"), "l"),
            (NSMakeRange(3, 0), NSMutableAttributedString(string: "Hel"), "l")
        ),
        (
            (NSMakeRange(4, 0), NSMutableAttributedString(string: "Hell"), "o"),
            (NSMakeRange(4, 0), NSMutableAttributedString(string: "Hell"), "o")
        ),
    ]
    
    func testBasicInput() {
        let handler = TextViewKeyboardWorkaroundHandler(debugTiming: true)
        
        let range = NSMakeRange(0, 0)
        let replacementText = "H"
        let oldText = NSMutableAttributedString(string: "")
        
        let expectRange = NSMakeRange(0, 0)
        let expectReplacementText = "H"
        let expectFullText = NSMutableAttributedString(string: "")
        
        let vec = [((range, oldText, replacementText), (expectRange, expectFullText, expectReplacementText))]
        
        executeTest(for: handler, testVectorAndExpect: vec)
    }
    
    func testBasicDoubleTapSpace() {
        let handler = TextViewKeyboardWorkaroundHandler(debugTiming: true)
        let vec = [
            helloWord,
            [
                (
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " "),
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " ")
                ),
                (
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Hello "), " "),
                    (NSMakeRange(5, 1), NSMutableAttributedString(string: "Hello "), ".")
                ),
            ],
        ].flatMap { $0 }
        
        executeTest(for: handler, testVectorAndExpect: vec)
    }
    
    func testDoubleTapSpaceAfterBackspace() {
        let handler = TextViewKeyboardWorkaroundHandler(debugTiming: true)
        let vec = [
            helloWord,
            [
                (
                    (NSMakeRange(5, -1), NSMutableAttributedString(string: "Hello"), ""),
                    (NSMakeRange(5, -1), NSMutableAttributedString(string: "Hello"), "")
                ),
                (
                    (NSMakeRange(4, 0), NSMutableAttributedString(string: "Hell"), "o"),
                    (NSMakeRange(4, 0), NSMutableAttributedString(string: "Hell"), "o")
                ),
                (
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " "),
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " ")
                ),
                (
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Hello "), " "),
                    (NSMakeRange(5, 1), NSMutableAttributedString(string: "Hello "), ".")
                ),
            ],
        ].flatMap { $0 }
        
        executeTest(for: handler, testVectorAndExpect: vec)
    }
    
    func testBasicPunctuationMark() {
        let handler = TextViewKeyboardWorkaroundHandler(debugTiming: true)
        let vec = [
            [
                (
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "Hello"),
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "Hello")
                ),
                (
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " "),
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " ")
                ),
                (
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Hello "), "?"),
                    (NSMakeRange(5, 1), NSMutableAttributedString(string: "Hello "), "? ")
                ),
            ],
        ].flatMap { $0 }
        
        executeTest(for: handler, testVectorAndExpect: vec)
    }
    
    func test1() {
        let handler = TextViewKeyboardWorkaroundHandler(debugTiming: true)
        let vec = [
            [
                (
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "H"),
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "H")
                ),
                (
                    (NSMakeRange(1, 0), NSMutableAttributedString(string: "H"), "e"),
                    (NSMakeRange(1, 0), NSMutableAttributedString(string: "H"), "e")
                ),
                (
                    (NSMakeRange(2, 0), NSMutableAttributedString(string: "He"), "l"),
                    (NSMakeRange(2, 0), NSMutableAttributedString(string: "He"), "l")
                ),
                (
                    (NSMakeRange(3, 0), NSMutableAttributedString(string: "Hel"), "l"),
                    (NSMakeRange(3, 0), NSMutableAttributedString(string: "Hel"), "l")
                ),
                (
                    (NSMakeRange(4, 0), NSMutableAttributedString(string: "Hell"), "o"),
                    (NSMakeRange(4, 0), NSMutableAttributedString(string: "Hell"), "o")
                ),
                (
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " "),
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " ")
                ),
                (
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Hello "), "w"),
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Hello "), "w")
                ),
                (
                    (NSMakeRange(7, 0), NSMutableAttributedString(string: "Hello w"), "o"),
                    (NSMakeRange(7, 0), NSMutableAttributedString(string: "Hello w"), "o")
                ),
                (
                    (NSMakeRange(8, 0), NSMutableAttributedString(string: "Hello wo"), "r"),
                    (NSMakeRange(8, 0), NSMutableAttributedString(string: "Hello wo"), "r")
                ),
                (
                    (NSMakeRange(9, 0), NSMutableAttributedString(string: "Hello wor"), "l"),
                    (NSMakeRange(9, 0), NSMutableAttributedString(string: "Hello wor"), "l")
                ),
                (
                    (NSMakeRange(10, 0), NSMutableAttributedString(string: "Hello worl"), "d"),
                    (NSMakeRange(10, 0), NSMutableAttributedString(string: "Hello worl"), "d")
                ),
            ],
        ].flatMap { $0 }
        
        executeTest(for: handler, testVectorAndExpect: vec)
    }
    
    func test2() {
        let handler = TextViewKeyboardWorkaroundHandler(debugTiming: true)
        let vec = [
            [
                (
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "H"),
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "H")
                ),
                (
                    (NSMakeRange(1, 0), NSMutableAttributedString(string: "H"), "e"),
                    (NSMakeRange(1, 0), NSMutableAttributedString(string: "H"), "e")
                ),
                (
                    (NSMakeRange(2, 0), NSMutableAttributedString(string: "He"), "l"),
                    (NSMakeRange(2, 0), NSMutableAttributedString(string: "He"), "l")
                ),
                (
                    (NSMakeRange(3, 0), NSMutableAttributedString(string: "Hel"), "l"),
                    (NSMakeRange(3, 0), NSMutableAttributedString(string: "Hel"), "l")
                ),
                (
                    (NSMakeRange(4, 0), NSMutableAttributedString(string: "Hell"), "o"),
                    (NSMakeRange(4, 0), NSMutableAttributedString(string: "Hell"), "o")
                ),
                (
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " "),
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " ")
                ),
                (
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Hello "), " "),
                    (NSMakeRange(5, 1), NSMutableAttributedString(string: "Hello "), ".")
                ),
                (
                    (NSMakeRange(6, 1), NSMutableAttributedString(string: "Hello. "), ""),
                    (NSMakeRange(6, 1), NSMutableAttributedString(string: "Hello. "), "")
                ),
                (
                    (NSMakeRange(5, 1), NSMutableAttributedString(string: "Hello."), ""),
                    (NSMakeRange(5, 1), NSMutableAttributedString(string: "Hello."), "")
                ),
                (
                    (NSMakeRange(4, 1), NSMutableAttributedString(string: "Hello"), ""),
                    (NSMakeRange(4, 1), NSMutableAttributedString(string: "Hello"), "")
                ),
                (
                    (NSMakeRange(3, 1), NSMutableAttributedString(string: "Hell"), ""),
                    (NSMakeRange(3, 1), NSMutableAttributedString(string: "Hell"), "")
                ),
                (
                    (NSMakeRange(2, 1), NSMutableAttributedString(string: "Hel"), ""),
                    (NSMakeRange(2, 1), NSMutableAttributedString(string: "Hel"), "")
                ),
                (
                    (NSMakeRange(1, 1), NSMutableAttributedString(string: "He"), ""),
                    (NSMakeRange(1, 1), NSMutableAttributedString(string: "He"), "")
                ),
                (
                    (NSMakeRange(0, 1), NSMutableAttributedString(string: "H"), ""),
                    (NSMakeRange(0, 1), NSMutableAttributedString(string: "H"), "")
                ),
                (
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "Test"),
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "Test")
                ),
                (
                    (NSMakeRange(4, 0), NSMutableAttributedString(string: "Test"), " "),
                    (NSMakeRange(4, 0), NSMutableAttributedString(string: "Test"), " ")
                ),
                (
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Test "), " "),
                    (NSMakeRange(4, 1), NSMutableAttributedString(string: "Test "), ".")
                ),
                (
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Test."), " "),
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Test."), " ")
                ),
                (
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Test. "), "results"),
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Test. "), "results")
                ),
                (
                    (NSMakeRange(13, 0), NSMutableAttributedString(string: "Test. results"), " "),
                    (NSMakeRange(13, 0), NSMutableAttributedString(string: "Test. results"), " ")
                ),
                (
                    (NSMakeRange(14, 0), NSMutableAttributedString(string: "Test. results "), "?"),
                    (NSMakeRange(13, 1), NSMutableAttributedString(string: "Test. results "), "? ")
                ),
                (
                    (NSMakeRange(15, 0), NSMutableAttributedString(string: "Test. results? "), " Hello"),
                    (NSMakeRange(15, 0), NSMutableAttributedString(string: "Test. results? "), " Hello")
                ),
                (
                    (NSMakeRange(21, 0), NSMutableAttributedString(string: "Test. results?  Hello"), " "),
                    (NSMakeRange(21, 0), NSMutableAttributedString(string: "Test. results?  Hello"), " ")
                ),
                (
                    (NSMakeRange(22, 0), NSMutableAttributedString(string: "Test. results?  Hello "), "!"),
                    (NSMakeRange(21, 1), NSMutableAttributedString(string: "Test. results?  Hello "), "! ")
                ),
                (
                    (NSMakeRange(23, 0), NSMutableAttributedString(string: "Test. results?  Hello! "), " Test"),
                    (NSMakeRange(23, 0), NSMutableAttributedString(string: "Test. results?  Hello! "), " Test")
                ),
                (
                    (NSMakeRange(28, 0), NSMutableAttributedString(string: "Test. results?  Hello!  Test"), " "),
                    (NSMakeRange(28, 0), NSMutableAttributedString(string: "Test. results?  Hello!  Test"), " ")
                ),
                (
                    (NSMakeRange(29, 0), NSMutableAttributedString(string: "Test. results?  Hello!  Test "), "."),
                    (NSMakeRange(28, 1), NSMutableAttributedString(string: "Test. results?  Hello!  Test "), ". ")
                ),
                (
                    (NSMakeRange(0, 30), NSMutableAttributedString(string: "Test. results?  Hello!  Test. "), ""),
                    (NSMakeRange(0, 30), NSMutableAttributedString(string: "Test. results?  Hello!  Test. "), "")
                ),
                (
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "Hello"),
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "Hello")
                ),
                (
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " "),
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " ")
                ),
                (
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Hello "), " "),
                    (NSMakeRange(5, 1), NSMutableAttributedString(string: "Hello "), ".")
                ),
                (
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Hello."), " "),
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Hello."), " ")
                ),
                (
                    (NSMakeRange(7, 0), NSMutableAttributedString(string: "Hello. "), "👋"),
                    (NSMakeRange(7, 0), NSMutableAttributedString(string: "Hello. "), "👋")
                ),
                (
                    (NSMakeRange(9, 0), NSMutableAttributedString(string: "Hello. 👋"), " "),
                    (NSMakeRange(9, 0), NSMutableAttributedString(string: "Hello. 👋"), " ")
                ),
                (
                    (NSMakeRange(10, 0), NSMutableAttributedString(string: "Hello. 👋 "), " "),
                    (NSMakeRange(9, 1), NSMutableAttributedString(string: "Hello. 👋 "), ".")
                ),
                (
                    (NSMakeRange(10, 0), NSMutableAttributedString(string: "Hello. 👋."), " "),
                    (NSMakeRange(10, 0), NSMutableAttributedString(string: "Hello. 👋."), " ")
                ),
                (
                    (NSMakeRange(11, 0), NSMutableAttributedString(string: "Hello. 👋. "), "📱"),
                    (NSMakeRange(11, 0), NSMutableAttributedString(string: "Hello. 👋. "), "📱")
                ),
                (
                    (NSMakeRange(13, 0), NSMutableAttributedString(string: "Hello. 👋. 📱"), "📱"),
                    (NSMakeRange(13, 0), NSMutableAttributedString(string: "Hello. 👋. 📱"), "📱")
                ),
                (
                    (NSMakeRange(15, 0), NSMutableAttributedString(string: "Hello. 👋. 📱📱"), "📱"),
                    (NSMakeRange(15, 0), NSMutableAttributedString(string: "Hello. 👋. 📱📱"), "📱")
                ),
                (
                    (NSMakeRange(17, 0), NSMutableAttributedString(string: "Hello. 👋. 📱📱📱"), "📱"),
                    (NSMakeRange(17, 0), NSMutableAttributedString(string: "Hello. 👋. 📱📱📱"), "📱")
                ),
                (
                    (NSMakeRange(19, 0), NSMutableAttributedString(string: "Hello. 👋. 📱📱📱📱"), " "),
                    (NSMakeRange(19, 0), NSMutableAttributedString(string: "Hello. 👋. 📱📱📱📱"), " ")
                ),
                (
                    (NSMakeRange(20, 0), NSMutableAttributedString(string: "Hello. 👋. 📱📱📱📱 "), " "),
                    (NSMakeRange(19, 1), NSMutableAttributedString(string: "Hello. 👋. 📱📱📱📱 "), ".")
                ),
                (
                    (NSMakeRange(17, 0), NSMutableAttributedString(string: "Hello. 👋. 📱📱📱📱. "), " "),
                    (NSMakeRange(17, 0), NSMutableAttributedString(string: "Hello. 👋. 📱📱📱📱. "), " ")
                ),
                (
                    (NSMakeRange(18, 0), NSMutableAttributedString(string: "Hello. 👋. 📱📱📱 📱. "), " "),
                    (NSMakeRange(18, 0), NSMutableAttributedString(string: "Hello. 👋. 📱📱📱 📱. "), " ")
                ),
                (
                    (NSMakeRange(0, 24), NSMutableAttributedString(string: "Hello. 👋. 📱📱📱   📱. "), ""),
                    (NSMakeRange(0, 24), NSMutableAttributedString(string: "Hello. 👋. 📱📱📱   📱. "), "")
                ),
                (
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "H"),
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "H")
                ),
                (
                    (NSMakeRange(1, 0), NSMutableAttributedString(string: "H"), "e"),
                    (NSMakeRange(1, 0), NSMutableAttributedString(string: "H"), "e")
                ),
                (
                    (NSMakeRange(2, 0), NSMutableAttributedString(string: "He"), "l"),
                    (NSMakeRange(2, 0), NSMutableAttributedString(string: "He"), "l")
                ),
                (
                    (NSMakeRange(3, 0), NSMutableAttributedString(string: "Hel"), "l"),
                    (NSMakeRange(3, 0), NSMutableAttributedString(string: "Hel"), "l")
                ),
                (
                    (NSMakeRange(4, 0), NSMutableAttributedString(string: "Hell"), "o"),
                    (NSMakeRange(4, 0), NSMutableAttributedString(string: "Hell"), "o")
                ),
                (
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " "),
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hello"), " ")
                ),
                (
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Hello "), "W"),
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Hello "), "W")
                ),
                (
                    (NSMakeRange(7, 0), NSMutableAttributedString(string: "Hello W"), "o"),
                    (NSMakeRange(7, 0), NSMutableAttributedString(string: "Hello W"), "o")
                ),
                (
                    (NSMakeRange(8, 0), NSMutableAttributedString(string: "Hello Wo"), "r"),
                    (NSMakeRange(8, 0), NSMutableAttributedString(string: "Hello Wo"), "r")
                ),
                (
                    (NSMakeRange(9, 0), NSMutableAttributedString(string: "Hello Wor"), "l"),
                    (NSMakeRange(9, 0), NSMutableAttributedString(string: "Hello Wor"), "l")
                ),
                (
                    (NSMakeRange(10, 0), NSMutableAttributedString(string: "Hello Worl"), "d"),
                    (NSMakeRange(10, 0), NSMutableAttributedString(string: "Hello Worl"), "d")
                ),
                (
                    (NSMakeRange(11, 0), NSMutableAttributedString(string: "Hello World"), " "),
                    (NSMakeRange(11, 0), NSMutableAttributedString(string: "Hello World"), " ")
                ),
                (
                    (NSMakeRange(12, 0), NSMutableAttributedString(string: "Hello World "), " "),
                    (NSMakeRange(11, 1), NSMutableAttributedString(string: "Hello World "), ".")
                ),
            ],
        ].flatMap { $0 }
        
        executeTest(for: handler, testVectorAndExpect: vec)
    }
    
    func test3() {
        let handler = TextViewKeyboardWorkaroundHandler(debugTiming: true)
        let vec = [
            [
                (
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "h"),
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "h")
                ),
                (
                    (NSMakeRange(1, 0), NSMutableAttributedString(string: "h"), "e"),
                    (NSMakeRange(1, 0), NSMutableAttributedString(string: "h"), "e")
                ),
                (
                    (NSMakeRange(2, 0), NSMutableAttributedString(string: "he"), "l"),
                    (NSMakeRange(2, 0), NSMutableAttributedString(string: "he"), "l")
                ),
                (
                    (NSMakeRange(0, 3), NSMutableAttributedString(string: "hel"), "hello"),
                    (NSMakeRange(0, 3), NSMutableAttributedString(string: "hel"), "hello")
                ),
                (
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "hello"), "!"),
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "hello"), "! ")
                ),
                (
                    (NSMakeRange(6, 1), NSMutableAttributedString(string: "hello! "), ""),
                    (NSMakeRange(6, 1), NSMutableAttributedString(string: "hello! "), "")
                ),
                (
                    (NSMakeRange(5, 1), NSMutableAttributedString(string: "hello!"), ""),
                    (NSMakeRange(5, 1), NSMutableAttributedString(string: "hello!"), "")
                ),
                (
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "hello"), " "),
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "hello"), " ")
                ),
                (
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "hello "), "w"),
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "hello "), "w")
                ),
                (
                    (NSMakeRange(7, 0), NSMutableAttributedString(string: "hello w"), "o"),
                    (NSMakeRange(7, 0), NSMutableAttributedString(string: "hello w"), "o")
                ),
                (
                    (NSMakeRange(8, 0), NSMutableAttributedString(string: "hello wo"), "r"),
                    (NSMakeRange(8, 0), NSMutableAttributedString(string: "hello wo"), "r")
                ),
                (
                    (NSMakeRange(6, 3), NSMutableAttributedString(string: "hello wor"), "world"),
                    (NSMakeRange(6, 3), NSMutableAttributedString(string: "hello wor"), "world")
                ),
                (
                    (NSMakeRange(11, 0), NSMutableAttributedString(string: "hello world"), " "),
                    (NSMakeRange(11, 0), NSMutableAttributedString(string: "hello world"), " ")
                ),
                (
                    (NSMakeRange(12, 0), NSMutableAttributedString(string: "hello world "), "!"),
                    (NSMakeRange(11, 1), NSMutableAttributedString(string: "hello world "), "! ")
                ),
                (
                    (NSMakeRange(13, 0), NSMutableAttributedString(string: "hello world! "), "T"),
                    (NSMakeRange(13, 0), NSMutableAttributedString(string: "hello world! "), "T")
                ),
                (
                    (NSMakeRange(14, 0), NSMutableAttributedString(string: "hello world! T"), "h"),
                    (NSMakeRange(14, 0), NSMutableAttributedString(string: "hello world! T"), "h")
                ),
                (
                    (NSMakeRange(15, 0), NSMutableAttributedString(string: "hello world! Th"), "i"),
                    (NSMakeRange(15, 0), NSMutableAttributedString(string: "hello world! Th"), "i")
                ),
                (
                    (NSMakeRange(16, 0), NSMutableAttributedString(string: "hello world! Thi"), "s"),
                    (NSMakeRange(16, 0), NSMutableAttributedString(string: "hello world! Thi"), "s")
                ),
                (
                    (NSMakeRange(17, 0), NSMutableAttributedString(string: "hello world! This"), " "),
                    (NSMakeRange(17, 0), NSMutableAttributedString(string: "hello world! This"), " ")
                ),
                (
                    (NSMakeRange(18, 0), NSMutableAttributedString(string: "hello world! This "), "i"),
                    (NSMakeRange(18, 0), NSMutableAttributedString(string: "hello world! This "), "i")
                ),
                (
                    (NSMakeRange(19, 0), NSMutableAttributedString(string: "hello world! This i"), "s"),
                    (NSMakeRange(19, 0), NSMutableAttributedString(string: "hello world! This i"), "s")
                ),
                (
                    (NSMakeRange(20, 0), NSMutableAttributedString(string: "hello world! This is"), " "),
                    (NSMakeRange(20, 0), NSMutableAttributedString(string: "hello world! This is"), " ")
                ),
                (
                    (NSMakeRange(21, 0), NSMutableAttributedString(string: "hello world! This is "), "a"),
                    (NSMakeRange(21, 0), NSMutableAttributedString(string: "hello world! This is "), "a")
                ),
                (
                    (NSMakeRange(22, 0), NSMutableAttributedString(string: "hello world! This is a"), " "),
                    (NSMakeRange(22, 0), NSMutableAttributedString(string: "hello world! This is a"), " ")
                ),
                (
                    (NSMakeRange(23, 0), NSMutableAttributedString(string: "hello world! This is a "), "t"),
                    (NSMakeRange(23, 0), NSMutableAttributedString(string: "hello world! This is a "), "t")
                ),
                (
                    (NSMakeRange(24, 0), NSMutableAttributedString(string: "hello world! This is a t"), "e"),
                    (NSMakeRange(24, 0), NSMutableAttributedString(string: "hello world! This is a t"), "e")
                ),
                (
                    (NSMakeRange(25, 0), NSMutableAttributedString(string: "hello world! This is a te"), "s"),
                    (NSMakeRange(25, 0), NSMutableAttributedString(string: "hello world! This is a te"), "s")
                ),
                (
                    (NSMakeRange(23, 3), NSMutableAttributedString(string: "hello world! This is a tes"), "test"),
                    (NSMakeRange(23, 3), NSMutableAttributedString(string: "hello world! This is a tes"), "test")
                ),
                (
                    (NSMakeRange(27, 0), NSMutableAttributedString(string: "hello world! This is a test"), " "),
                    (NSMakeRange(27, 0), NSMutableAttributedString(string: "hello world! This is a test"), " ")
                ),
                (
                    (NSMakeRange(28, 0), NSMutableAttributedString(string: "hello world! This is a test "), "!"),
                    (NSMakeRange(27, 1), NSMutableAttributedString(string: "hello world! This is a test "), "! ")
                ),
                (
                    (NSMakeRange(29, 0), NSMutableAttributedString(string: "hello world! This is a test! "), "C"),
                    (NSMakeRange(29, 0), NSMutableAttributedString(string: "hello world! This is a test! "), "C")
                ),
                (
                    (NSMakeRange(30, 0), NSMutableAttributedString(string: "hello world! This is a test! C"), "o"),
                    (NSMakeRange(30, 0), NSMutableAttributedString(string: "hello world! This is a test! C"), "o")
                ),
                (
                    (NSMakeRange(31, 0), NSMutableAttributedString(string: "hello world! This is a test! Co"), "m"),
                    (NSMakeRange(31, 0), NSMutableAttributedString(string: "hello world! This is a test! Co"), "m")
                ),
                (
                    (NSMakeRange(32, 0), NSMutableAttributedString(string: "hello world! This is a test! Com"), "p"),
                    (NSMakeRange(32, 0), NSMutableAttributedString(string: "hello world! This is a test! Com"), "p")
                ),
                (
                    (NSMakeRange(33, 0), NSMutableAttributedString(string: "hello world! This is a test! Comp"), "l"),
                    (NSMakeRange(33, 0), NSMutableAttributedString(string: "hello world! This is a test! Comp"), "l")
                ),
                (
                    (NSMakeRange(34, 0), NSMutableAttributedString(string: "hello world! This is a test! Compl"), "e"),
                    (NSMakeRange(34, 0), NSMutableAttributedString(string: "hello world! This is a test! Compl"), "e")
                ),
                (
                    (NSMakeRange(34, 1), NSMutableAttributedString(string: "hello world! This is a test! Comple"), ""),
                    (NSMakeRange(34, 1), NSMutableAttributedString(string: "hello world! This is a test! Comple"), "")
                ),
                (
                    (NSMakeRange(33, 1), NSMutableAttributedString(string: "hello world! This is a test! Compl"), ""),
                    (NSMakeRange(33, 1), NSMutableAttributedString(string: "hello world! This is a test! Compl"), "")
                ),
                (
                    (NSMakeRange(32, 1), NSMutableAttributedString(string: "hello world! This is a test! Comp"), ""),
                    (NSMakeRange(32, 1), NSMutableAttributedString(string: "hello world! This is a test! Comp"), "")
                ),
                (
                    (NSMakeRange(31, 1), NSMutableAttributedString(string: "hello world! This is a test! Com"), ""),
                    (NSMakeRange(31, 1), NSMutableAttributedString(string: "hello world! This is a test! Com"), "")
                ),
                (
                    (NSMakeRange(30, 1), NSMutableAttributedString(string: "hello world! This is a test! Co"), ""),
                    (NSMakeRange(30, 1), NSMutableAttributedString(string: "hello world! This is a test! Co"), "")
                ),
                (
                    (NSMakeRange(29, 1), NSMutableAttributedString(string: "hello world! This is a test! C"), ""),
                    (NSMakeRange(29, 1), NSMutableAttributedString(string: "hello world! This is a test! C"), "")
                ),
                (
                    (NSMakeRange(28, 1), NSMutableAttributedString(string: "hello world! This is a test! "), ""),
                    (NSMakeRange(28, 1), NSMutableAttributedString(string: "hello world! This is a test! "), "")
                ),
                (
                    (NSMakeRange(27, 1), NSMutableAttributedString(string: "hello world! This is a test!"), ""),
                    (NSMakeRange(27, 1), NSMutableAttributedString(string: "hello world! This is a test!"), "")
                ),
                (
                    (NSMakeRange(26, 1), NSMutableAttributedString(string: "hello world! This is a test"), ""),
                    (NSMakeRange(26, 1), NSMutableAttributedString(string: "hello world! This is a test"), "")
                ),
                (
                    (NSMakeRange(25, 1), NSMutableAttributedString(string: "hello world! This is a tes"), ""),
                    (NSMakeRange(25, 1), NSMutableAttributedString(string: "hello world! This is a tes"), "")
                ),
                (
                    (NSMakeRange(24, 1), NSMutableAttributedString(string: "hello world! This is a te"), ""),
                    (NSMakeRange(24, 1), NSMutableAttributedString(string: "hello world! This is a te"), "")
                ),
                (
                    (NSMakeRange(23, 1), NSMutableAttributedString(string: "hello world! This is a t"), ""),
                    (NSMakeRange(23, 1), NSMutableAttributedString(string: "hello world! This is a t"), "")
                ),
                (
                    (NSMakeRange(22, 1), NSMutableAttributedString(string: "hello world! This is a "), ""),
                    (NSMakeRange(22, 1), NSMutableAttributedString(string: "hello world! This is a "), "")
                ),
                (
                    (NSMakeRange(21, 1), NSMutableAttributedString(string: "hello world! This is a"), ""),
                    (NSMakeRange(21, 1), NSMutableAttributedString(string: "hello world! This is a"), "")
                ),
                (
                    (NSMakeRange(20, 1), NSMutableAttributedString(string: "hello world! This is "), ""),
                    (NSMakeRange(20, 1), NSMutableAttributedString(string: "hello world! This is "), "")
                ),
                (
                    (NSMakeRange(19, 1), NSMutableAttributedString(string: "hello world! This is"), ""),
                    (NSMakeRange(19, 1), NSMutableAttributedString(string: "hello world! This is"), "")
                ),
                (
                    (NSMakeRange(18, 1), NSMutableAttributedString(string: "hello world! This i"), ""),
                    (NSMakeRange(18, 1), NSMutableAttributedString(string: "hello world! This i"), "")
                ),
                (
                    (NSMakeRange(17, 1), NSMutableAttributedString(string: "hello world! This "), ""),
                    (NSMakeRange(17, 1), NSMutableAttributedString(string: "hello world! This "), "")
                ),
                (
                    (NSMakeRange(16, 1), NSMutableAttributedString(string: "hello world! This"), ""),
                    (NSMakeRange(16, 1), NSMutableAttributedString(string: "hello world! This"), "")
                ),
                (
                    (NSMakeRange(15, 1), NSMutableAttributedString(string: "hello world! Thi"), ""),
                    (NSMakeRange(15, 1), NSMutableAttributedString(string: "hello world! Thi"), "")
                ),
                (
                    (NSMakeRange(14, 1), NSMutableAttributedString(string: "hello world! Th"), ""),
                    (NSMakeRange(14, 1), NSMutableAttributedString(string: "hello world! Th"), "")
                ),
                (
                    (NSMakeRange(13, 1), NSMutableAttributedString(string: "hello world! T"), ""),
                    (NSMakeRange(13, 1), NSMutableAttributedString(string: "hello world! T"), "")
                ),
                (
                    (NSMakeRange(12, 1), NSMutableAttributedString(string: "hello world! "), ""),
                    (NSMakeRange(12, 1), NSMutableAttributedString(string: "hello world! "), "")
                ),
                (
                    (NSMakeRange(11, 1), NSMutableAttributedString(string: "hello world!"), ""),
                    (NSMakeRange(11, 1), NSMutableAttributedString(string: "hello world!"), "")
                ),
                (
                    (NSMakeRange(10, 1), NSMutableAttributedString(string: "hello world"), ""),
                    (NSMakeRange(10, 1), NSMutableAttributedString(string: "hello world"), "")
                ),
                (
                    (NSMakeRange(9, 1), NSMutableAttributedString(string: "hello worl"), ""),
                    (NSMakeRange(9, 1), NSMutableAttributedString(string: "hello worl"), "")
                ),
                (
                    (NSMakeRange(8, 1), NSMutableAttributedString(string: "hello wor"), ""),
                    (NSMakeRange(8, 1), NSMutableAttributedString(string: "hello wor"), "")
                ),
                (
                    (NSMakeRange(7, 1), NSMutableAttributedString(string: "hello wo"), ""),
                    (NSMakeRange(7, 1), NSMutableAttributedString(string: "hello wo"), "")
                ),
                (
                    (NSMakeRange(6, 1), NSMutableAttributedString(string: "hello w"), ""),
                    (NSMakeRange(6, 1), NSMutableAttributedString(string: "hello w"), "")
                ),
                (
                    (NSMakeRange(5, 1), NSMutableAttributedString(string: "hello "), ""),
                    (NSMakeRange(5, 1), NSMutableAttributedString(string: "hello "), "")
                ),
                (
                    (NSMakeRange(4, 1), NSMutableAttributedString(string: "hello"), ""),
                    (NSMakeRange(4, 1), NSMutableAttributedString(string: "hello"), "")
                ),
                (
                    (NSMakeRange(3, 1), NSMutableAttributedString(string: "hell"), ""),
                    (NSMakeRange(3, 1), NSMutableAttributedString(string: "hell"), "")
                ),
                (
                    (NSMakeRange(2, 1), NSMutableAttributedString(string: "hel"), ""),
                    (NSMakeRange(2, 1), NSMutableAttributedString(string: "hel"), "")
                ),
                (
                    (NSMakeRange(1, 1), NSMutableAttributedString(string: "he"), ""),
                    (NSMakeRange(1, 1), NSMutableAttributedString(string: "he"), "")
                ),
                (
                    (NSMakeRange(0, 1), NSMutableAttributedString(string: "h"), ""),
                    (NSMakeRange(0, 1), NSMutableAttributedString(string: "h"), "")
                ),
                (
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "H"),
                    (NSMakeRange(0, 0), NSMutableAttributedString(string: ""), "H")
                ),
                (
                    (NSMakeRange(1, 0), NSMutableAttributedString(string: "H"), "a"),
                    (NSMakeRange(1, 0), NSMutableAttributedString(string: "H"), "a")
                ),
                (
                    (NSMakeRange(2, 0), NSMutableAttributedString(string: "Ha"), "l"),
                    (NSMakeRange(2, 0), NSMutableAttributedString(string: "Ha"), "l")
                ),
                (
                    (NSMakeRange(3, 0), NSMutableAttributedString(string: "Hal"), "l"),
                    (NSMakeRange(3, 0), NSMutableAttributedString(string: "Hal"), "l")
                ),
                (
                    (NSMakeRange(0, 4), NSMutableAttributedString(string: "Hall"), "Hallo"),
                    (NSMakeRange(0, 4), NSMutableAttributedString(string: "Hall"), "Hallo")
                ),
                (
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hallo"), " "),
                    (NSMakeRange(5, 0), NSMutableAttributedString(string: "Hallo"), " ")
                ),
                (
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Hallo "), "H"),
                    (NSMakeRange(6, 0), NSMutableAttributedString(string: "Hallo "), "H")
                ),
                (
                    (NSMakeRange(7, 0), NSMutableAttributedString(string: "Hallo H"), "a"),
                    (NSMakeRange(7, 0), NSMutableAttributedString(string: "Hallo H"), "a")
                ),
                (
                    (NSMakeRange(8, 0), NSMutableAttributedString(string: "Hallo Ha"), "l"),
                    (NSMakeRange(8, 0), NSMutableAttributedString(string: "Hallo Ha"), "l")
                ),
                (
                    (NSMakeRange(9, 0), NSMutableAttributedString(string: "Hallo Hal"), "l"),
                    (NSMakeRange(9, 0), NSMutableAttributedString(string: "Hallo Hal"), "l")
                ),
                (
                    (NSMakeRange(10, 0), NSMutableAttributedString(string: "Hallo Hall"), "e"),
                    (NSMakeRange(10, 0), NSMutableAttributedString(string: "Hallo Hall"), "e")
                ),
                (
                    (NSMakeRange(11, 0), NSMutableAttributedString(string: "Hallo Halle"), " "),
                    (NSMakeRange(11, 0), NSMutableAttributedString(string: "Hallo Halle"), " ")
                ),
                (
                    (NSMakeRange(12, 0), NSMutableAttributedString(string: "Hallo Halle "), "!"),
                    (NSMakeRange(12, 0), NSMutableAttributedString(string: "Hallo Halle "), "!")
                ),
                (
                    (NSMakeRange(12, 1), NSMutableAttributedString(string: "Hallo Halle !"), ""),
                    (NSMakeRange(12, 1), NSMutableAttributedString(string: "Hallo Halle !"), "")
                ),
                (
                    (NSMakeRange(11, 1), NSMutableAttributedString(string: "Hallo Halle "), ""),
                    (NSMakeRange(11, 1), NSMutableAttributedString(string: "Hallo Halle "), "")
                ),
                (
                    (NSMakeRange(11, 0), NSMutableAttributedString(string: "Hallo Halle"), " "),
                    (NSMakeRange(11, 0), NSMutableAttributedString(string: "Hallo Halle"), " ")
                ),
                (
                    (NSMakeRange(12, 0), NSMutableAttributedString(string: "Hallo Halle "), "?"),
                    (NSMakeRange(12, 0), NSMutableAttributedString(string: "Hallo Halle "), "?")
                ),
                (
                    (NSMakeRange(12, 1), NSMutableAttributedString(string: "Hallo Halle ?"), ""),
                    (NSMakeRange(12, 1), NSMutableAttributedString(string: "Hallo Halle ?"), "")
                ),
                (
                    (NSMakeRange(11, 1), NSMutableAttributedString(string: "Hallo Halle "), ""),
                    (NSMakeRange(11, 1), NSMutableAttributedString(string: "Hallo Halle "), "")
                ),
                (
                    (NSMakeRange(10, 1), NSMutableAttributedString(string: "Hallo Halle"), ""),
                    (NSMakeRange(10, 1), NSMutableAttributedString(string: "Hallo Halle"), "")
                ),
                (
                    (NSMakeRange(10, 0), NSMutableAttributedString(string: "Hallo Hall"), "e"),
                    (NSMakeRange(10, 0), NSMutableAttributedString(string: "Hallo Hall"), "e")
                ),
                (
                    (NSMakeRange(11, 0), NSMutableAttributedString(string: "Hallo Halle"), "e"),
                    (NSMakeRange(11, 0), NSMutableAttributedString(string: "Hallo Halle"), "e")
                ),
                (
                    (NSMakeRange(11, 1), NSMutableAttributedString(string: "Hallo Hallee"), ""),
                    (NSMakeRange(11, 1), NSMutableAttributedString(string: "Hallo Hallee"), "")
                ),
                (
                    (NSMakeRange(10, 1), NSMutableAttributedString(string: "Hallo Halle"), ""),
                    (NSMakeRange(10, 1), NSMutableAttributedString(string: "Hallo Halle"), "")
                ),
                (
                    (NSMakeRange(9, 1), NSMutableAttributedString(string: "Hallo Hall"), ""),
                    (NSMakeRange(9, 1), NSMutableAttributedString(string: "Hallo Hall"), "")
                ),
                (
                    (NSMakeRange(8, 1), NSMutableAttributedString(string: "Hallo Hal"), ""),
                    (NSMakeRange(8, 1), NSMutableAttributedString(string: "Hallo Hal"), "")
                ),
                (
                    (NSMakeRange(7, 1), NSMutableAttributedString(string: "Hallo Ha"), ""),
                    (NSMakeRange(7, 1), NSMutableAttributedString(string: "Hallo Ha"), "")
                ),
                (
                    (NSMakeRange(6, 1), NSMutableAttributedString(string: "Hallo H"), ""),
                    (NSMakeRange(6, 1), NSMutableAttributedString(string: "Hallo H"), "")
                ),
                (
                    (NSMakeRange(5, 1), NSMutableAttributedString(string: "Hallo "), ""),
                    (NSMakeRange(5, 1), NSMutableAttributedString(string: "Hallo "), "")
                ),
                (
                    (NSMakeRange(4, 1), NSMutableAttributedString(string: "Hallo"), ""),
                    (NSMakeRange(4, 1), NSMutableAttributedString(string: "Hallo"), "")
                ),
                (
                    (NSMakeRange(3, 1), NSMutableAttributedString(string: "Hall"), ""),
                    (NSMakeRange(3, 1), NSMutableAttributedString(string: "Hall"), "")
                ),
                (
                    (NSMakeRange(2, 1), NSMutableAttributedString(string: "Hal"), ""),
                    (NSMakeRange(2, 1), NSMutableAttributedString(string: "Hal"), "")
                ),
                (
                    (NSMakeRange(1, 1), NSMutableAttributedString(string: "Ha"), ""),
                    (NSMakeRange(1, 1), NSMutableAttributedString(string: "Ha"), "")
                ),
                (
                    (NSMakeRange(0, 1), NSMutableAttributedString(string: "H"), ""),
                    (NSMakeRange(0, 1), NSMutableAttributedString(string: "H"), "")
                ),
            ],
        ].flatMap { $0 }
        
        executeTest(for: handler, testVectorAndExpect: vec)
    }
    
    private func executeTest(
        for handler: TextViewKeyboardWorkaroundHandler,
        testVectorAndExpect: [(input: InputType, output: OutputType)]
    ) {
        for (input, output) in testVectorAndExpect {
            let result = handler.nextTextViewChange(
                shouldChangeTextIn: input.range,
                replacementText: input.replacementText,
                oldText: input.oldText
            )
            
            XCTAssert(result.range == output.range, "Range is \(result.range) but should be \(output.range)")
            XCTAssert(
                result.newText == output.newText,
                "NewText is \"\(result.newText)\" but should be \"\(output.newText)\""
            )
            XCTAssert(
                result.fullText.string == output.fullText.string,
                "FullText is \"\(result.fullText.string)\" but should be \"\(output.fullText.string)\""
            )
        }
    }
}
