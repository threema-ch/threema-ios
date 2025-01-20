//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
@testable import Threema

class MentionsHelperTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testNoUnecessaryMentions() throws {
        let mentionsHelper = MentionsHelper()
        let testText = "Hello World"
        
        for i in 0..<testText.count {
            let addedText = "\(testText[i])"
            let range = NSMakeRange(i, 1)
            let recognizedMention = mentionsHelper.couldBeMention(text: addedText, location: range)
            assert(recognizedMention == nil)
        }
    }
    
    func testBasicMention() throws {
        let mentionsHelper = MentionsHelper()
        let testText = "@Hello World"
        
        for i in 0..<testText.count {
            let addedText = "\(testText[i])"
            let range = NSMakeRange(i, 0)
            
            print("\(addedText) - \(range)")
            let recognizedMention = mentionsHelper.couldBeMention(text: addedText, location: range)
            let startIndex = testText.index(testText.startIndex, offsetBy: 1)
            let endIndex = testText.index(testText.startIndex, offsetBy: 1 + i)
            
            let goldenSubstring = testText.suffix(from: startIndex).prefix(upTo: endIndex)
            print(goldenSubstring)
            assert(recognizedMention! == goldenSubstring)
        }
    }
    
    func testEditedMention() throws {
        let mentionsHelper = MentionsHelper()
        
        let insertionArray: [(text: String, range: NSRange, expectation: String)] = [
            ("@", NSMakeRange(0, 0), ""),
            ("H", NSMakeRange(1, 0), "H"),
            ("e", NSMakeRange(2, 0), "He"),
            ("", NSMakeRange(2, 1), "H"),
            ("e", NSMakeRange(2, 0), "He"),
            ("l", NSMakeRange(3, 0), "Hel"),
            ("l", NSMakeRange(4, 0), "Hell"),
            ("o", NSMakeRange(5, 0), "Hello"),
        ]
        
        for insertion in insertionArray {
            let recognizedMention = mentionsHelper.couldBeMention(text: insertion.text, location: insertion.range)
            
            assert(recognizedMention != nil)
            assert(recognizedMention == insertion.expectation)
        }
    }
    
    func testBasicDeletedMention() throws {
        let mentionsHelper = MentionsHelper()
        
        let insertionArray: [(text: String, range: NSRange, expectation: String)] = [
            ("H", NSMakeRange(0, 0), ""),
            ("", NSMakeRange(0, 1), ""),
            ("H", NSMakeRange(0, 0), ""),
            ("e", NSMakeRange(1, 0), ""),
            ("l", NSMakeRange(2, 0), ""),
            ("l", NSMakeRange(3, 0), ""),
            ("o", NSMakeRange(4, 0), ""),
            (" ", NSMakeRange(5, 0), ""),
            ("W", NSMakeRange(6, 0), ""),
            ("o", NSMakeRange(7, 0), ""),
            ("r", NSMakeRange(8, 0), ""),
            ("l", NSMakeRange(9, 0), ""),
            ("d", NSMakeRange(10, 0), ""),
            (" ", NSMakeRange(11, 0), ""),
            ("@", NSMakeRange(12, 0), ""),
            ("d", NSMakeRange(13, 0), "d"),
            ("o", NSMakeRange(14, 0), "do"),
            ("l", NSMakeRange(15, 0), "dol"),
            ("o", NSMakeRange(16, 0), "dolo"),
            ("r", NSMakeRange(17, 0), "dolor"),
            (" ", NSMakeRange(18, 0), "dolor "),
            ("i", NSMakeRange(19, 0), "dolor i"),
            ("", NSMakeRange(19, 1), "dolor "),
            ("s", NSMakeRange(19, 0), "dolor s"),
            ("i", NSMakeRange(20, 0), "dolor si"),
            ("t", NSMakeRange(21, 0), "dolor sit"),
            (" ", NSMakeRange(22, 0), "dolor sit "),
            ("a", NSMakeRange(23, 0), "dolor sit a"),
            ("n", NSMakeRange(24, 0), "dolor sit an"),
            ("e", NSMakeRange(25, 0), "dolor sit ane"),
            ("m", NSMakeRange(26, 0), "dolor sit anem"),
            ("", NSMakeRange(26, 1), "dolor sit ane"),
            ("", NSMakeRange(25, 1), "dolor sit an"),
            ("", NSMakeRange(24, 1), "dolor sit a"),
            ("", NSMakeRange(23, 1), "dolor sit "),
            ("", NSMakeRange(22, 1), "dolor sit"),
            ("", NSMakeRange(21, 1), "dolor si"),
            ("", NSMakeRange(20, 1), "dolor s"),
            ("", NSMakeRange(19, 1), "dolor "),
            ("", NSMakeRange(18, 1), "dolor"),
            ("", NSMakeRange(17, 1), "dolo"),
            ("", NSMakeRange(16, 1), "dol"),
            ("", NSMakeRange(15, 1), "do"),
            ("", NSMakeRange(14, 1), "d"),
            ("", NSMakeRange(13, 1), ""),
            ("", NSMakeRange(12, 1), ""),
            ("", NSMakeRange(11, 1), ""),
            (" ", NSMakeRange(11, 0), ""),
            ("@", NSMakeRange(12, 0), ""),
            ("l", NSMakeRange(13, 0), "l"),
            ("o", NSMakeRange(14, 0), "lo"),
            ("r", NSMakeRange(15, 0), "lor"),
            ("e", NSMakeRange(16, 0), "lore"),
            ("m", NSMakeRange(17, 0), "lorem"),
            ("", NSMakeRange(17, 1), "lore"),
            ("", NSMakeRange(16, 1), "lor"),
            ("", NSMakeRange(15, 1), "lo"),
            ("", NSMakeRange(14, 1), "l"),
            ("", NSMakeRange(0, 14), ""),
        ]
        
        for insertion in insertionArray {
            let recognizedMention = mentionsHelper.couldBeMention(text: insertion.text, location: insertion.range)
            
            if recognizedMention != nil {
                assert(recognizedMention == insertion.expectation)
            }
            else {
                assert(insertion.expectation == "")
            }
        }
    }
    
    func testSecondUnrelatedMention() throws {
        let mentionsHelper = MentionsHelper()
        
        let insertionArray: [(text: String, range: NSRange, expectation: String)] = [
            ("Q", NSMakeRange(0, 0), ""),
            ("u", NSMakeRange(1, 0), ""),
            ("o", NSMakeRange(2, 0), ""),
            ("d", NSMakeRange(3, 0), ""),
            (" ", NSMakeRange(4, 0), ""),
            ("i", NSMakeRange(5, 0), ""),
            ("m", NSMakeRange(6, 0), ""),
            ("p", NSMakeRange(7, 0), ""),
            ("e", NSMakeRange(8, 0), ""),
            ("d", NSMakeRange(9, 0), ""),
            ("i", NSMakeRange(10, 0), ""),
            ("t", NSMakeRange(11, 0), ""),
            ("impeding", NSMakeRange(5, 7), ""),
            (" ", NSMakeRange(13, 0), ""),
            ("q", NSMakeRange(14, 0), ""),
            ("u", NSMakeRange(15, 0), ""),
            ("i", NSMakeRange(16, 0), ""),
            (" ", NSMakeRange(17, 0), ""),
            ("t", NSMakeRange(18, 0), ""),
            ("o", NSMakeRange(19, 0), ""),
            ("t", NSMakeRange(20, 0), ""),
            ("a", NSMakeRange(21, 0), ""),
            ("m", NSMakeRange(22, 0), ""),
            ("total", NSMakeRange(18, 5), ""),
            (".", NSMakeRange(23, 0), ""),
            (" ", NSMakeRange(24, 0), ""),
            ("@", NSMakeRange(25, 0), ""),
            ("c", NSMakeRange(26, 0), "c"),
            ("u", NSMakeRange(27, 0), "cu"),
            ("l", NSMakeRange(28, 0), "cul"),
            ("p", NSMakeRange(29, 0), "culp"),
            ("a", NSMakeRange(30, 0), "culpa"),
            (" ", NSMakeRange(31, 0), "culpa "),
            ("d", NSMakeRange(32, 0), "culpa d"),
            ("o", NSMakeRange(33, 0), "culpa do"),
            ("l", NSMakeRange(34, 0), "culpa dol"),
            ("o", NSMakeRange(35, 0), "culpa dolo"),
            ("r", NSMakeRange(36, 0), "culpa dolor"),
            ("i", NSMakeRange(37, 0), "culpa dolori"),
            ("b", NSMakeRange(38, 0), "culpa dolorib"),
            ("u", NSMakeRange(39, 0), "culpa doloribu"),
            ("s", NSMakeRange(40, 0), "culpa doloribus"),
            (" ", NSMakeRange(41, 0), "culpa doloribus "),
            ("o", NSMakeRange(42, 0), "culpa doloribus o"),
            ("d", NSMakeRange(43, 0), "culpa doloribus od"),
            ("i", NSMakeRange(44, 0), "culpa doloribus odi"),
            ("t", NSMakeRange(45, 0), "culpa doloribus odit"),
            (" ", NSMakeRange(46, 0), "culpa doloribus odit "),
            ("a", NSMakeRange(47, 0), "culpa doloribus odit a"),
            ("b", NSMakeRange(48, 0), "culpa doloribus odit ab"),
            ("an", NSMakeRange(47, 2), "culpa doloribus odit an"),
            (".", NSMakeRange(49, 0), "culpa doloribus odit an."),
            (" ", NSMakeRange(50, 0), "culpa doloribus odit an. "),
            ("@", NSMakeRange(51, 0), ""),
            ("q", NSMakeRange(52, 0), "q"),
            ("u", NSMakeRange(53, 0), "qu"),
            ("i", NSMakeRange(54, 0), "qui"),
            ("a", NSMakeRange(55, 0), "quia"),
            (" ", NSMakeRange(56, 0), "quia "),
            ("i", NSMakeRange(57, 0), "quia i"),
            ("u", NSMakeRange(58, 0), "quia iu"),
            ("s", NSMakeRange(59, 0), "quia ius"),
            ("t", NSMakeRange(60, 0), "quia iust"),
            ("o", NSMakeRange(61, 0), "quia iusto"),
            ("justo", NSMakeRange(57, 5), "quia justo"),
            (" ", NSMakeRange(62, 0), "quia justo "),
            ("e", NSMakeRange(63, 0), "quia justo e"),
            ("t", NSMakeRange(64, 0), "quia justo et"),
            (" ", NSMakeRange(65, 0), "quia justo et "),
            ("o", NSMakeRange(66, 0), "quia justo et o"),
            ("f", NSMakeRange(67, 0), "quia justo et of"),
            ("f", NSMakeRange(68, 0), "quia justo et off"),
            ("i", NSMakeRange(69, 0), "quia justo et offi"),
            ("c", NSMakeRange(70, 0), "quia justo et offic"),
            ("i", NSMakeRange(71, 0), "quia justo et offici"),
            ("i", NSMakeRange(72, 0), "quia justo et officii"),
            ("i", NSMakeRange(73, 0), "quia justo et officiii"),
            ("s", NSMakeRange(74, 0), "quia justo et officiiis"),
            (" ", NSMakeRange(75, 0), "quia justo et officiiis "),
            ("q", NSMakeRange(76, 0), "quia justo et officiiis q"),
            ("u", NSMakeRange(77, 0), "quia justo et officiiis qu"),
            ("i", NSMakeRange(78, 0), "quia justo et officiiis qui"),
            (" ", NSMakeRange(79, 0), "quia justo et officiiis qui "),
            ("v", NSMakeRange(80, 0), "quia justo et officiiis qui v"),
            ("o", NSMakeRange(81, 0), "quia justo et officiiis qui vo"),
            ("l", NSMakeRange(82, 0), "quia justo et officiiis qui vol"),
            ("u", NSMakeRange(83, 0), "quia justo et officiiis qui volu"),
            ("p", NSMakeRange(84, 0), "quia justo et officiiis qui volup"),
            ("t", NSMakeRange(85, 0), "quia justo et officiiis qui volupt"),
            ("a", NSMakeRange(86, 0), "quia justo et officiiis qui volupta"),
            ("t", NSMakeRange(87, 0), "quia justo et officiiis qui voluptat"),
            ("e", NSMakeRange(88, 0), "quia justo et officiiis qui voluptate"),
            ("m", NSMakeRange(89, 0), "quia justo et officiiis qui voluptatem"),
            ("voluntarism", NSMakeRange(80, 10), "quia justo et officiiis qui voluntarism"),
            (".", NSMakeRange(91, 0), "quia justo et officiiis qui voluntarism."),
            (" ", NSMakeRange(92, 0), "quia justo et officiiis qui voluntarism. "),
            ("D", NSMakeRange(93, 0), "quia justo et officiiis qui voluntarism. D"),
            ("o", NSMakeRange(94, 0), "quia justo et officiiis qui voluntarism. Do"),
            ("l", NSMakeRange(95, 0), "quia justo et officiiis qui voluntarism. Dol"),
            ("o", NSMakeRange(96, 0), "quia justo et officiiis qui voluntarism. Dolo"),
            ("r", NSMakeRange(97, 0), "quia justo et officiiis qui voluntarism. Dolor"),
            ("e", NSMakeRange(98, 0), "quia justo et officiiis qui voluntarism. Dolore"),
            ("m", NSMakeRange(99, 0), "quia justo et officiiis qui voluntarism. Dolorem"),
            ("Dolores", NSMakeRange(93, 7), "quia justo et officiiis qui voluntarism. Dolores"),
            (" ", NSMakeRange(100, 0), "quia justo et officiiis qui voluntarism. Dolores "),
            ("i", NSMakeRange(101, 0), "quia justo et officiiis qui voluntarism. Dolores i"),
            ("p", NSMakeRange(102, 0), "quia justo et officiiis qui voluntarism. Dolores ip"),
            ("s", NSMakeRange(103, 0), "quia justo et officiiis qui voluntarism. Dolores ips"),
            ("u", NSMakeRange(104, 0), "quia justo et officiiis qui voluntarism. Dolores ipsu"),
            ("m", NSMakeRange(105, 0), "quia justo et officiiis qui voluntarism. Dolores ipsum"),
            (" ", NSMakeRange(106, 0), "quia justo et officiiis qui voluntarism. Dolores ipsum "),
            ("f", NSMakeRange(107, 0), "quia justo et officiiis qui voluntarism. Dolores ipsum f"),
            ("a", NSMakeRange(108, 0), "quia justo et officiiis qui voluntarism. Dolores ipsum fa"),
            ("c", NSMakeRange(109, 0), "quia justo et officiiis qui voluntarism. Dolores ipsum fac"),
            ("i", NSMakeRange(110, 0), "quia justo et officiiis qui voluntarism. Dolores ipsum faci"),
            ("l", NSMakeRange(111, 0), "quia justo et officiiis qui voluntarism. Dolores ipsum facil"),
            ("", NSMakeRange(111, 1), "quia justo et officiiis qui voluntarism. Dolores ipsum faci"),
            ("i", NSMakeRange(111, 0), "quia justo et officiiis qui voluntarism. Dolores ipsum facii"),
            ("s", NSMakeRange(112, 0), "quia justo et officiiis qui voluntarism. Dolores ipsum faciis"),
            ("", NSMakeRange(112, 1), "quia justo et officiiis qui voluntarism. Dolores ipsum facii"),
            ("", NSMakeRange(111, 1), "quia justo et officiiis qui voluntarism. Dolores ipsum faci"),
            ("", NSMakeRange(110, 1), "quia justo et officiiis qui voluntarism. Dolores ipsum fac"),
            ("", NSMakeRange(109, 1), "quia justo et officiiis qui voluntarism. Dolores ipsum fa"),
            ("", NSMakeRange(108, 1), "quia justo et officiiis qui voluntarism. Dolores ipsum f"),
            ("", NSMakeRange(107, 1), "quia justo et officiiis qui voluntarism. Dolores ipsum "),
            ("", NSMakeRange(106, 1), "quia justo et officiiis qui voluntarism. Dolores ipsum"),
            ("", NSMakeRange(105, 1), "quia justo et officiiis qui voluntarism. Dolores ipsu"),
            ("", NSMakeRange(104, 1), "quia justo et officiiis qui voluntarism. Dolores ips"),
            ("", NSMakeRange(103, 1), "quia justo et officiiis qui voluntarism. Dolores ip"),
            ("", NSMakeRange(102, 1), "quia justo et officiiis qui voluntarism. Dolores i"),
            ("", NSMakeRange(101, 1), "quia justo et officiiis qui voluntarism. Dolores "),
            ("", NSMakeRange(100, 1), "quia justo et officiiis qui voluntarism. Dolores"),
            ("", NSMakeRange(99, 1), "quia justo et officiiis qui voluntarism. Dolore"),
            ("", NSMakeRange(98, 1), "quia justo et officiiis qui voluntarism. Dolor"),
            ("", NSMakeRange(97, 1), "quia justo et officiiis qui voluntarism. Dolo"),
            ("", NSMakeRange(96, 1), "quia justo et officiiis qui voluntarism. Dol"),
            ("", NSMakeRange(95, 1), "quia justo et officiiis qui voluntarism. Do"),
            ("", NSMakeRange(94, 1), "quia justo et officiiis qui voluntarism. D"),
            ("", NSMakeRange(93, 1), "quia justo et officiiis qui voluntarism. "),
            ("", NSMakeRange(92, 1), "quia justo et officiiis qui voluntarism."),
            ("", NSMakeRange(91, 1), "quia justo et officiiis qui voluntarism"),
            ("", NSMakeRange(90, 1), "quia justo et officiiis qui voluntaris"),
            ("", NSMakeRange(89, 1), "quia justo et officiiis qui voluntari"),
            ("", NSMakeRange(88, 1), "quia justo et officiiis qui voluntar"),
            ("", NSMakeRange(87, 1), "quia justo et officiiis qui volunta"),
            ("", NSMakeRange(86, 1), "quia justo et officiiis qui volunt"),
            ("", NSMakeRange(85, 1), "quia justo et officiiis qui volun"),
            ("", NSMakeRange(84, 1), "quia justo et officiiis qui volu"),
            ("", NSMakeRange(83, 1), "quia justo et officiiis qui vol"),
            ("", NSMakeRange(82, 1), "quia justo et officiiis qui vo"),
            ("", NSMakeRange(81, 1), "quia justo et officiiis qui v"),
            ("", NSMakeRange(80, 1), "quia justo et officiiis qui "),
            ("", NSMakeRange(79, 1), "quia justo et officiiis qui"),
            ("", NSMakeRange(78, 1), "quia justo et officiiis qu"),
            ("", NSMakeRange(77, 1), "quia justo et officiiis q"),
            ("", NSMakeRange(76, 1), "quia justo et officiiis "),
            ("", NSMakeRange(75, 1), "quia justo et officiiis"),
            ("", NSMakeRange(74, 1), "quia justo et officiii"),
            ("", NSMakeRange(73, 1), "quia justo et officii"),
            ("", NSMakeRange(72, 1), "quia justo et offici"),
            ("", NSMakeRange(71, 1), "quia justo et offic"),
            ("", NSMakeRange(70, 1), "quia justo et offi"),
            ("", NSMakeRange(69, 1), "quia justo et off"),
            ("", NSMakeRange(68, 1), "quia justo et of"),
            ("", NSMakeRange(67, 1), "quia justo et o"),
            ("", NSMakeRange(66, 1), "quia justo et "),
            ("", NSMakeRange(65, 1), "quia justo et"),
            ("", NSMakeRange(64, 1), "quia justo e"),
            ("", NSMakeRange(63, 1), "quia justo "),
            ("", NSMakeRange(62, 1), "quia justo"),
            ("", NSMakeRange(61, 1), "quia just"),
            ("", NSMakeRange(60, 1), "quia jus"),
            ("", NSMakeRange(59, 1), "quia ju"),
            ("", NSMakeRange(58, 1), "quia j"),
            ("", NSMakeRange(57, 1), "quia "),
            ("", NSMakeRange(56, 1), "quia"),
            ("", NSMakeRange(55, 1), "qui"),
            ("", NSMakeRange(54, 1), "qu"),
            ("", NSMakeRange(53, 1), "q"),
            ("", NSMakeRange(52, 1), ""),
            ("", NSMakeRange(51, 1), ""),
            ("", NSMakeRange(50, 1), ""),
            (" ", NSMakeRange(50, 0), ""),
            ("@", NSMakeRange(51, 0), ""),
            ("m", NSMakeRange(52, 0), "m"),
            ("a", NSMakeRange(53, 0), "ma"),
            ("i", NSMakeRange(54, 0), "mai"),
            ("o", NSMakeRange(55, 0), "maio"),
            ("r", NSMakeRange(56, 0), "maior"),
            ("e", NSMakeRange(57, 0), "maiore"),
            ("s", NSMakeRange(58, 0), "maiores"),
            (" ", NSMakeRange(59, 0), "maiores "),
            ("m", NSMakeRange(60, 0), "maiores m"),
            ("o", NSMakeRange(61, 0), "maiores mo"),
            ("l", NSMakeRange(62, 0), "maiores mol"),
            ("l", NSMakeRange(63, 0), "maiores moll"),
            ("i", NSMakeRange(64, 0), "maiores molli"),
            ("t", NSMakeRange(65, 0), "maiores mollit"),
            ("i", NSMakeRange(66, 0), "maiores molliti"),
            ("a", NSMakeRange(67, 0), "maiores mollitia"),
            (" ", NSMakeRange(68, 0), "maiores mollitia "),
            (".", NSMakeRange(69, 0), "maiores mollitia ."),
            ("", NSMakeRange(69, 1), "maiores mollitia "),
            ("", NSMakeRange(68, 1), "maiores mollitia"),
            (".", NSMakeRange(68, 0), "maiores mollitia."),
        ]
        
        for insertion in insertionArray {
            let recognizedMention = mentionsHelper.couldBeMention(text: insertion.text, location: insertion.range)
            
            if recognizedMention != nil {
                assert(recognizedMention == insertion.expectation)
            }
            else {
                assert(insertion.expectation == "")
            }
        }
    }
}
