//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

class DateFormatterTests_de_DE: XCTestCase {
    
    let localeIdentifier = "de_DE"
    
    override func setUp() {
        DateFormatter.locale = Locale(identifier: localeIdentifier)
    }
    
    // Expected date strings
    let expectedShortStyleDateTime_de_DE = "01.02.20, 13:14"
    let expectedShortStyleDateTimeSeconds_de_DE = "01.02.20, 13:14:15"
    let expectedMediumStyleDateTime_de_DE = "01.02.2020, 13:14:15"
    let expectedMediumStyleDateShortStyleTime_de_DE = "01.02.2020, 13:14"
    let expectedLongStyleDateTime_de_DE_prefix = "1. Februar 2020 um 13:14:15 "
    let expectedShortStyleTimeNoDate_de_DE = "13:14"
    
    let expectedGetShortDate_de_DE = "1.2.2020"
    let expectedGetDayMonthAndYear_de_DE = "Sa. 01. Feb. 2020"
    let expectedGetFullDateFor_de_DE = "Sa. 01. Feb. 2020, 13:14"
    let expectedGetYearFor_de_DE = "2020"
    
    let expectedRelativeMediumDateYesterday_de_DE = "Gestern"
    let expectedRelativeMediumDateThisYear_de_DE = " 01. Jan."
    let expectedRelativeMediumDateLastCalendarYear_de_DE = " 31. Dez. "
    let expectedRelativeMediumDateMoreThanAYearAgo_de_DE = "Fr. 01. Feb. 2019"
    let expectedRelativeTimeTodayAndMediumDateOtherwiseToday_de_DE = "13:14"
    let expectedRelativeTimeTodayAndMediumDateOtherwiseYesterday_de_DE = "Gestern"

    let expectedRelativeLongStyleDateShortStyleTimeTomorrow_de_DE = "Morgen, 02:03"
    let expectedRelativeLongStyleDateShortStyleTimeToday_de_DE = "Heute, 13:14"
    
    let expectedAccessibilityDateTime_de_DE: String = {
        if #available(iOS 16.0, *) {
            return "1. Februar 2020 um 13:14"
        }
        else {
            return "1. Februar 2020, 13:14"
        }
    }()
    
    let expectedAccessibilityRelativeDayTime_de_DE = "1. Februar 2020 um 13:14"
    
    // MARK: - Test formats provided by the system
    
    func testShortStyleDateTime() {
        let actual: String = DateFormatter.shortStyleDateTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedShortStyleDateTime_de_DE)
    }
    
    func testShortStyleDateTimeSeconds() {
        let actual: String = DateFormatter.shortStyleDateTimeSeconds(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedShortStyleDateTimeSeconds_de_DE)
    }
    
    func testMediumStyleDateTime() {
        let actual: String = DateFormatter.mediumStyleDateTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedMediumStyleDateTime_de_DE)
    }
    
    func testMediumStyleDateShortStyleTime() {
        let actual = DateFormatter.mediumStyleDateShortStyleTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedMediumStyleDateShortStyleTime_de_DE)
    }
    
    func testLongStyleDateTime() {
        let actual: String = DateFormatter.longStyleDateTime(DateFormatterTests.testDate)
        
        // As time zone suffix changes between system time zones we can only test for the prefix
        XCTAssertTrue(actual.hasPrefix(expectedLongStyleDateTime_de_DE_prefix))
    }
    
    func testShortStyleTimeNoDate() {
        let actual = DateFormatter.shortStyleTimeNoDate(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedShortStyleTimeNoDate_de_DE)
    }
    
    func testRelativeLongStyleDateShortStyleTimeTomorrow() {
        let actual = DateFormatter.relativeLongStyleDateShortStyleTime(DateFormatterTests.testDateTomorrowAt20304)
        
        XCTAssertEqual(actual, expectedRelativeLongStyleDateShortStyleTimeTomorrow_de_DE)
    }
    
    func testRelativeLongStyleDateShortStyleTimeToday() {
        let actual = DateFormatter.relativeLongStyleDateShortStyleTime(DateFormatterTests.testDateTodayAt131415)
        
        XCTAssertEqual(actual, expectedRelativeLongStyleDateShortStyleTimeToday_de_DE)
    }
    
    // MARK: - Test custom formats
    
    func testGetShortDate() {
        let actual = DateFormatter.getShortDate(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetShortDate_de_DE)
    }
    
    func testGetDayMonthAndYear() {
        let actual = DateFormatter.getDayMonthAndYear(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetDayMonthAndYear_de_DE)
    }
    
    func testGetFullDateFor() {
        let actual = DateFormatter.getFullDate(for: DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetFullDateFor_de_DE)
    }
    
    func testGetFullDateForWithReinitalization() {
        DateFormatter.forceReinitialize()
        DateFormatter.locale = Locale(identifier: localeIdentifier)
        
        let actual = DateFormatter.getFullDate(for: DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetFullDateFor_de_DE)
    }
    
    func testGetYear() {
        let actual = DateFormatter.getYear(for: DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetYearFor_de_DE)
    }
    
    // MARK: - Test to `Date` converter
    
    func testGetDateFromDayMonthAndYearDateStringWithReinitalization() throws {
        DateFormatter.forceReinitialize()
        DateFormatter.locale = Locale(identifier: localeIdentifier)
        
        let actual = try XCTUnwrap(DateFormatter.getDateFromDayMonthAndYearDateString(expectedGetDayMonthAndYear_de_DE))
        
        let comparisonResult = Calendar.current.compare(actual, to: DateFormatterTests.testDate, toGranularity: .day)
        
        XCTAssertEqual(comparisonResult, .orderedSame, "The dates are not equal up to the day")
    }
    
    func testGetDateFromFullDateStringWithReinitalization() throws {
        DateFormatter.forceReinitialize()
        DateFormatter.locale = Locale(identifier: localeIdentifier)
        
        let actual = try XCTUnwrap(DateFormatter.getDateFromFullDateString(expectedGetFullDateFor_de_DE))
        
        let comparisonResult = Calendar.current.compare(actual, to: DateFormatterTests.testDate, toGranularity: .minute)
        
        XCTAssertEqual(comparisonResult, .orderedSame, "The dates are not equal up to the second")
    }
    
    // MARK: - Test relative custom formats
    
    func testRelativeMediumDateYesterday() throws {
        let twentyFourHoursAgo = Date(timeIntervalSinceNow: -(60 * 60 * 24))
        
        let actual = DateFormatter.relativeMediumDate(for: twentyFourHoursAgo)
        
        XCTAssertEqual(actual, expectedRelativeMediumDateYesterday_de_DE)
    }
    
    func testRelativeMediumDateThisYearWithReset() throws {
        try XCTSkipIf(
            DateFormatterTests.todayIsInTheFirstSevenDaysOfTheYear,
            "Because the date is relative and based on the current year this will not work properly if today is in the first week of the year"
        )
        
        let expected =
            "\(DateFormatterTests.formattedShortWeekday(DateFormatterTests.testDateThisYear, localeIdentifier))\(expectedRelativeMediumDateThisYear_de_DE)"

        DateFormatter.forceReinitialize()
        DateFormatter.locale = Locale(identifier: localeIdentifier)
        
        let actual = DateFormatter.relativeMediumDate(for: DateFormatterTests.testDateThisYear)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testRelativeMediumDateLastCalendarYear() throws {
        try XCTSkipIf(
            DateFormatterTests.todayIsInTheFirstSevenDaysOfTheYear,
            "Because the date is relative and based on the current year this will not work properly if today is in the first week of the year"
        )
        
        let expected =
            "\(DateFormatterTests.formattedShortWeekday(DateFormatterTests.testDateLastCalendarYear, localeIdentifier))\(expectedRelativeMediumDateLastCalendarYear_de_DE)\(DateFormatterTests.formattedFullYear(DateFormatterTests.testDateLastCalendarYear, localeIdentifier))"

        let actual = DateFormatter.relativeMediumDate(for: DateFormatterTests.testDateLastCalendarYear)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testRelativeMediumDateMoreThanAYearAgo() {
        let actual = DateFormatter.relativeMediumDate(for: DateFormatterTests.testDateMoreThanAYearAgo)
        
        XCTAssertEqual(actual, expectedRelativeMediumDateMoreThanAYearAgo_de_DE)
    }
    
    func testRelativeTimeTodayAndMediumDateOtherwiseToday() {
        let actual = DateFormatter
            .relativeTimeTodayAndMediumDateOtherwise(for: DateFormatterTests.testDateTodayAt131415)
        
        XCTAssertEqual(actual, expectedRelativeTimeTodayAndMediumDateOtherwiseToday_de_DE)
    }
    
    func testRelativeTimeTodayAndMediumDateOtherwiseYesterday() throws {
        let twentyFourHoursAgo = Date(timeIntervalSinceNow: -(60 * 60 * 24))
        
        let actual = DateFormatter.relativeTimeTodayAndMediumDateOtherwise(for: twentyFourHoursAgo)
        
        XCTAssertEqual(actual, expectedRelativeTimeTodayAndMediumDateOtherwiseYesterday_de_DE)
    }
    
    // MARK: - Test accessibility formats
    
    func testAccessibilityDateTime() {
        let actual = DateFormatter.accessibilityDateTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedAccessibilityDateTime_de_DE)
    }
    
    func testAccessibilityRelativeDayTime() {
        let actual = DateFormatter.accessibilityRelativeDayTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedAccessibilityRelativeDayTime_de_DE)
    }
}
