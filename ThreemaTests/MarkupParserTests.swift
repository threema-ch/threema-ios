//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021 Threema GmbH
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

class MarkupParserTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        
        // necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }

    override func tearDown() {
        super.tearDown()
    }
    
    func testParseBold() {
        let testString = "hello *there*"
        let parsed = parse(text: testString)
        XCTAssertEqual("hello there", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 1)
        expect(parsedTokenType: .bold, parsed: parsed, start: 7, end: 12)
    }
    
    func testParseItalic() {
        let testString = "hello _there_"
        let parsed = parse(text: testString)
        XCTAssertEqual("hello there", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 1)
        expect(parsedTokenType: .italic, parsed: parsed, start: 7, end: 12)
    }
    
    func testParseStrikethrough() {
        let testString = "hello ~there~"
        let parsed = parse(text: testString)
        XCTAssertEqual("hello there", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 1)
        expect(parsedTokenType: .strikethrough, parsed: parsed, start: 7, end: 12)
    }

    func testParseTwoBold() {
        let testString = "two *bold* *parts*"
        let parsed = parse(text: testString)
        XCTAssertEqual("two bold parts", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 2)
        expect(parsedTokenType: .bold, parsed: parsed, start: 5, end: 9)
        expect(parsedTokenType: .bold, parsed: parsed, start: 12, end: 17)
    }
    
    func testParseTwoItalic() {
        let testString = "two _italic_ _bits_"
        let parsed = parse(text: testString)
        XCTAssertEqual("two italic bits", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 2)
        expect(parsedTokenType: .italic, parsed: parsed, start: 5, end: 11)
        expect(parsedTokenType: .italic, parsed: parsed, start: 14, end: 18)
    }
    
    func testParseTwoStrikethrough() {
        let testString = "two ~striked~ ~through~"
        let parsed = parse(text: testString)
        XCTAssertEqual("two striked through", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 2)
        expect(parsedTokenType: .strikethrough, parsed: parsed, start: 5, end: 12)
        expect(parsedTokenType: .strikethrough, parsed: parsed, start: 15, end: 22)
    }
    
    func testParseMixedMarkup() {
        let testString = "*bold* and _italic_"
        let parsed = parse(text: testString)
        XCTAssertEqual("bold and italic", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 2)
        expect(parsedTokenType: .bold, parsed: parsed, start: 1, end: 5)
        expect(parsedTokenType: .italic, parsed: parsed, start: 12, end: 18)
    }
    
    func testParseMixedMarkupNested() {
        let testString = "*bold with _italic_*"
        let parsed = parse(text: testString)
        XCTAssertEqual("bold with italic", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 2)
        expect(parsedTokenType: .bold, parsed: parsed, start: 1, end: 11)
        expect(parsedTokenType: .boldItalic, parsed: parsed, start: 12, end: 18)
    }
    
    func testParseAtWordBoundaries1() {
        let testString = "(*bold*)"
        let parsed = parse(text: testString)
        XCTAssertEqual("(bold)", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 1)
        expect(parsedTokenType: .bold, parsed: parsed, start: 2, end: 6)
    }
    
    func testParseAtWordBoundaries2() {
        let testString = "¡*Threema* es fantástico!"
        let parsed = parse(text: testString)
        XCTAssertEqual("¡Threema es fantástico!", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 1)
        expect(parsedTokenType: .bold, parsed: parsed, start: 2, end: 9)
    }
    
    func testParseAtWordBoundaries3() {
        let testString = "«_great_ service»"
        let parsed = parse(text: testString)
        XCTAssertEqual("«great service»", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 1)
        expect(parsedTokenType: .italic, parsed: parsed, start: 2, end: 7)
    }
    
    func testParseAtWordBoundaries4() {
        let testString = "\"_great_ service\""
        let parsed = parse(text: testString)
        XCTAssertEqual("\"great service\"", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 1)
        expect(parsedTokenType: .italic, parsed: parsed, start: 2, end: 7)
    }
    
    func testParseAtWordBoundaries5() {
        let testString = "*bold*…"
        let parsed = parse(text: testString)
        XCTAssertEqual("bold…", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 1)
        expect(parsedTokenType: .bold, parsed: parsed, start: 1, end: 5)
    }
    
    func testParseAtWordBoundaries6() {
        let testString = "_<a href=\"https://threema.ch\">Threema</a>_"
        let parsed = parse(text: testString)
        XCTAssertEqual("<a href=\"https://threema.ch\">Threema</a>", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 1)
        expect(parsedTokenType: .italic, parsed: parsed, start: 1, end: 41)
    }
    
    func testOnlyWordBoundaries1() {
        let testString = "so not_really_italic"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testOnlyWordBoundaries2() {
        let testString = "invalid*bold*stuff"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testOnlyWordBoundaries3() {
        let testString = "no~strike~through"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testOnlyWordBoundaries4() {
        let testString = "<_< >_>"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testOnlyWordBoundaries5() {
        let testString = "<a href=\"https://threema.ch\">_Threema_</a>"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testOnlyWordBoundaries6() {
        let testString = "*bold_but_no~strike~through*"
        let parsed = parse(text: testString)
        XCTAssertEqual("bold_but_no~strike~through", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 1)
        expect(parsedTokenType: .bold, parsed: parsed, start: 1, end: 27)
    }
    
    func testAvoidBreakingURLs1() {
        let testString = "https://example.com/_output_/"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testAvoidBreakingURLs2() {
        let testString = "https://example.com/*output*/"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testAvoidBreakingURLs3() {
        let testString = "https://example.com?__twitter_impression=true"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testAvoidBreakingURLs4() {
        let testString = "https://example.com?_twitter_impression=true"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testAvoidBreakingURLs5() {
        let testString = "https://en.wikipedia.org/wiki/Java_class_file *nice*"
        let parsed = parse(text: testString)
        XCTAssertEqual("https://en.wikipedia.org/wiki/Java_class_file nice", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 1)
        expect(parsedTokenType: .bold, parsed: parsed, start: 47, end: 51)
    }
    
    func testAvoidBreakingURLs6() {
        let testString = "https://example.com/image_-_1.jpg"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testURLs() {
        let testString = "http://www.threema.ch or https://www.threema.ch"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 0, end: 21)
        expect(parsedTokenType: .url, parsed: parsed, start: 25, end: 47)
    }
    
    func testURLs2() {
        let testString = "http://www.threema.ch or https://www.threema.ch or short www.threema.ch"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 0, end: 21)
        expect(parsedTokenType: .url, parsed: parsed, start: 25, end: 47)
        expect(parsedTokenType: .url, parsed: parsed, start: 57, end: 71)
    }
    
    func testURLs3() {
        let testString = "Hallo http://www.threema.ch und nicht http://www.google.ch"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 6, end: 27)
        expect(parsedTokenType: .url, parsed: parsed, start: 38, end: 58)
    }
    
    func testURLs4() {
        let testString = "Hallo http://www.threema.ch und nicht http://google.ch"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 6, end: 27)
        expect(parsedTokenType: .url, parsed: parsed, start: 38, end: 54)
    }
    
    func testURLs5() {
        let testString = "Hallo 🚀🍬❤️‍🔥 http://www.threema.ch und nicht http://google.ch"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 16, end: 37)
        expect(parsedTokenType: .url, parsed: parsed, start: 48, end: 64)
    }
    
    func testURLs6() {
        let testString = "Test (www.threema.ch"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 6, end: 20)
    }
    
    func testURLs7() {
        let testString = "Test )www.threema.ch"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 6, end: 20)
    }
    
    func testURLs8() {
        let testString = "Test |www.threema.ch"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 6, end: 20)
    }
    
    func testURLWithEmoji1() {
        let testString = "Hi 😎 http://www.threema.ch/ check it out!"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 6, end: 28)
    }
    
    func testURLWithEmoji2() {
        let testString = "Hi 😎 http://www.threema.ch/"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 6, end: 28)
    }
    
    func testURLWithEmoji3() {
        let testString = "Hi 😎 http://www.threema.ch"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 6, end: 27)
    }
    
    func testURLWithEmoji4() {
        let testString = "Hi 😎 http://www.threema.ch/test.php"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 6, end: 36)
    }
    
    func testURLWithEmoji5() {
        let testString = "Hi 😎 http://www.threema.ch/test.php Check it out!"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 6, end: 36)
    }
    
    func testURLWithoutEmoji1() {
        let testString = "Hi http://www.threema.ch/ check it out!"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 3, end: 25)
    }
    
    func testURLWithoutEmoji2() {
        let testString = "Hi http://www.threema.ch check it out!"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 3, end: 24)
    }
    
    func testURLWithoutHttp1() {
        let testString = "Hi www.threema.ch/ check it out!"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 3, end: 18)
    }
    
    func testURLWithoutHttp2() {
        let testString = "Hi 😎 www.threema.ch/ check it out!"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 6, end: 21)
    }
        
    func testURLWithUmlaut() {
        let testString = "https://gfrör.li"
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 0, end: 16)
    }
    
    func testWithoutRTLO() {
        let testString = "https://legit.okay/files/".appending("pm.asia")
        let parsed = parse(text: testString, parseURL: true)
        expect(parsedTokenType: .url, parsed: parsed, start: 0, end: 32)
    }
    
    func testWithRTLO() {
        let testString = "https://legit.okay/files/".appending(String(unicodeScalarLiteral: UnicodeScalarType("u202E")))
            .appending("pm.asia")
        let parsed = parse(text: testString, parseURL: true)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testIgnoreInvalidMarkup1() {
        let testString = "*invalid markup (do not parse)_"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testIgnoreInvalidMarkup2() {
        let testString = "random *asterisk"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testNotAcrossNewlines1() {
        let testString = "*First line\n and a new one. (do not parse)*"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testNotAcrossNewlines2() {
        let testString = "*\nbegins with linebreak. (do not parse)*"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testNotAcrossNewlines3() {
        let testString = "*Just some text. But it ends with newline (do not parse)\n*"
        let parsed = parse(text: testString)
        expectAttributedCount(parsed: parsed, expectedCount: 0)
    }
    
    func testNotAcrossNewlines4() {
        let testString = "_*first line*\n*second* line_"
        let parsed = parse(text: testString)
        XCTAssertEqual("_first line\nsecond line_", parsedWithoutMarkups(parsed: parsed))
        expectAttributedCount(parsed: parsed, expectedCount: 2)
        expect(parsedTokenType: .bold, parsed: parsed, start: 2, end: 12)
        expect(parsedTokenType: .bold, parsed: parsed, start: 15, end: 21)
    }
    
    func testPreviewString() {
        let testString = "Hello @[@@@@@@@@]. How *are* _you_?"
        let expectedString = "Hello @\(BundleUtil.localizedString(forKey: "mentions_all")). How are you?"
        
        let parsedString = MarkupParser().previewString(for: testString)
        
        XCTAssertEqual(parsedString, expectedString)
    }
    
    private func expectAttributedCount(parsed: NSAttributedString, expectedCount: Int) {
        var totalCount = 0
        parsed.enumerateAttributes(in: NSRange(location: 0, length: parsed.length)) { attributes, _, _ in
            if let tokenType = attributes[NSAttributedString.Key.tokenType] as? MarkupParser.TokenType {
                switch tokenType {
                case .bold, .italic, .strikethrough, .boldItalic:
                    totalCount += 1
                default:
                    break
                }
            }
        }
        XCTAssertEqual(expectedCount, totalCount)
    }
    
    private func expect(parsedTokenType: MarkupParser.TokenType, parsed: NSAttributedString, start: Int, end: Int) {
        var foundCount = 0
        var foundTokenType: MarkupParser.TokenType?
        var foundRange: NSRange?
        
        parsed.enumerateAttributes(in: NSRange(location: 0, length: parsed.length)) { attributes, range, _ in
            if let tokenType = attributes[NSAttributedString.Key.tokenType] as? MarkupParser.TokenType {
                print("Range is \(range)")
                if tokenType == parsedTokenType, range.location == start, range.length == end - start {
                    foundTokenType = tokenType
                    foundRange = range
                    foundCount += 1
                }
            }
        }
        
        XCTAssertEqual(1, foundCount, "Found more then 1 markup in this range")
        XCTAssertNotNil(foundTokenType, "Wrong token type")
        XCTAssertNotNil(foundRange, "Wrong start or end")
    }
    
    private func parse(text: String, parseURL: Bool = false) -> NSAttributedString {
        let parser = MarkupParser()
        return parser.markify(
            attributedString: NSAttributedString(string: text),
            font: UIFont.preferredFont(forTextStyle: .body),
            parseURL: parseURL,
            forTests: true
        )
    }
    
    private func parsedWithoutMarkups(parsed: NSAttributedString) -> String {
        let parser = MarkupParser()
        return parser.removeMarkupsFromParse(parsed: parsed).string
    }
}
