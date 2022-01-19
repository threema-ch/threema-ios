//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

class DateFormatterTests_en_US: XCTestCase {
    
    let localeIdentifier = "en_US"
    
    override func setUp() {
        DateFormatter.locale = Locale(identifier: localeIdentifier)
    }
    
    // Expected date strings
    let expectedShortStyleDateTime_en_US = "2/1/20, 1:14 PM"
    let expectedShortStyleDateTimeSeconds_en_US = "2/1/20, 1:14:15 PM"
    let expectedMediumStyleDateTime_en_US = "Feb 1, 2020 at 1:14:15 PM"
    let expectedMediumStyleDateShortStyleTime_en_US = "Feb 1, 2020 at 1:14 PM"
    let expectedLongStyleDateTime_en_US_prefix = "February 1, 2020 at 1:14:15 PM "
    let expectedShortStyleTimeNoDate_en_US = "1:14 PM"
    
    let expectedGetShortDate_en_US = "2/1/2020"
    let expectedGetDayMonthAndYear_en_US = "Sat, Feb 01, 2020"
    let expectedGetFullDateFor_en_US = "Sat, Feb 01, 2020, 1:14 PM"
    
    let expectedRelativeMediumDateYesterday_en_US = "Yesterday"
    let expectedRelativeMediumDateThisYear_en_US = ", Jan 02"
    let expectedRelativeMediumDateLastCalendarYear_en_US = ", Dec 31, "
    let expectedRelativeMediumDateMoreThanAYearAgo_en_US = "Fri, Feb 01, 2019"
    
    let expectedAccessibilityDateTime_en_US = "February 1, 2020, 1:14 PM"
    let expectedAccessibilityRelativeDayTime_en_US = "February 1, 2020 at 1:14 PM"
    
    // MARK: - Test formats provided by the system
    
    func testShortStyleDateTime() {
        let actual: String = DateFormatter.shortStyleDateTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedShortStyleDateTime_en_US)
    }
    
    func testShortStyleDateTimeSeconds() {
        let actual: String = DateFormatter.shortStyleDateTimeSeconds(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedShortStyleDateTimeSeconds_en_US)
    }
    
    func testMediumStyleDateTime() {
        let actual: String = DateFormatter.mediumStyleDateTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedMediumStyleDateTime_en_US)
    }
    
    func testMediumStyleDateShortStyleTime() {
        let actual = DateFormatter.mediumStyleDateShortStyleTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedMediumStyleDateShortStyleTime_en_US)
    }
    
    func testLongStyleDateTime() {
        let actual: String = DateFormatter.longStyleDateTime(DateFormatterTests.testDate)
        
        // As time zone suffix changes between system time zones we can only test for the prefix
        XCTAssertTrue(actual.hasPrefix(expectedLongStyleDateTime_en_US_prefix))
    }
    
    func testShortStyleTimeNoDate() {
        let actual = DateFormatter.shortStyleTimeNoDate(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedShortStyleTimeNoDate_en_US)
    }
    
    // MARK: - Test custom formats
    
    func testGetShortDate() {
        let actual = DateFormatter.getShortDate(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetShortDate_en_US)
    }
    
    func testGetDayMonthAndYear() {
        let actual = DateFormatter.getDayMonthAndYear(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetDayMonthAndYear_en_US)
    }
    
    func testGetFullDateFor() {
        let actual = DateFormatter.getFullDate(for: DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetFullDateFor_en_US)
    }
    
    func testGetFullDateForWithReinitalization() {
        DateFormatter.forceReinitialize()
        DateFormatter.locale = Locale(identifier: localeIdentifier)
        
        let actual = DateFormatter.getFullDate(for: DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetFullDateFor_en_US)
    }
    
    // MARK: - Test to `Date` converter
    
    func testGetDateFromDayMonthAndYearDateStringWithReinitalization() throws {
        DateFormatter.forceReinitialize()
        DateFormatter.locale = Locale(identifier: localeIdentifier)
        
        let actual = try XCTUnwrap(DateFormatter.getDateFromDayMonthAndYearDateString(expectedGetDayMonthAndYear_en_US))
        
        let comparisonResult = Calendar.current.compare(actual, to: DateFormatterTests.testDate, toGranularity: .day)
        
        XCTAssertEqual(comparisonResult, .orderedSame, "The dates are not equal up to the day")
    }
    
    func testGetDateFromFullDateStringWithReinitalization() throws {
        DateFormatter.forceReinitialize()
        DateFormatter.locale = Locale(identifier: localeIdentifier)
        
        let actual = try XCTUnwrap(DateFormatter.getDateFromFullDateString(expectedGetFullDateFor_en_US))
        
        let comparisonResult = Calendar.current.compare(actual, to: DateFormatterTests.testDate, toGranularity: .minute)
        
        XCTAssertEqual(comparisonResult, .orderedSame, "The dates are not equal up to the second")
    }
    
    // MARK: - Test relative custom formats
    
    func testRelativeMediumDateYesterday() throws {
        let twentyFourHoursAgo = Date(timeIntervalSinceNow: -(60 * 60 * 24))

        let actual = DateFormatter.relativeMediumDate(for: twentyFourHoursAgo)
        
        XCTAssertEqual(actual, expectedRelativeMediumDateYesterday_en_US)
    }
    
    func testRelativeMediumDateThisYear() {
        let expected = "\(DateFormatterTests.formattedShortWeekday(DateFormatterTests.testDateThisYear, localeIdentifier))\(expectedRelativeMediumDateThisYear_en_US)"
        
        let actual = DateFormatter.relativeMediumDate(for: DateFormatterTests.testDateThisYear)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testRelativeMediumDateLastCalendarYear() {
        let expected = "\(DateFormatterTests.formattedShortWeekday(DateFormatterTests.testDateLastCalendarYear, localeIdentifier))\(expectedRelativeMediumDateLastCalendarYear_en_US)\(DateFormatterTests.formattedFullYear(DateFormatterTests.testDateLastCalendarYear, localeIdentifier))"
        
        let actual = DateFormatter.relativeMediumDate(for: DateFormatterTests.testDateLastCalendarYear)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testRelativeMediumDateMoreThanAYearAgo() {
        let actual = DateFormatter.relativeMediumDate(for: DateFormatterTests.testDateMoreThanAYearAgo)
        
        XCTAssertEqual(actual, expectedRelativeMediumDateMoreThanAYearAgo_en_US)
    }
    
    // MARK: - Test accessibility formats
    
    func testAccessibilityDateTime() {
        let actual = DateFormatter.accessibilityDateTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedAccessibilityDateTime_en_US)
    }
    
    func testAccessibilityRelativeDayTime() {
        let actual = DateFormatter.accessibilityRelativeDayTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedAccessibilityRelativeDayTime_en_US)
    }
}


