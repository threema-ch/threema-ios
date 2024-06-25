//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2024 Threema GmbH
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

class DateFormatterTests_fr_CH: XCTestCase {
    
    let localeIdentifier = "fr_CH"
    
    override func setUp() {
        DateFormatter.locale = Locale(identifier: localeIdentifier)
    }
    
    // Expected date strings
    let expectedShortStyleDateTime_fr_CH = "01.02.20 13:14"
    let expectedShortStyleDateTimeSeconds_fr_CH = "01.02.20 13:14:15"
    let expectedMediumStyleDateTime_fr_CH = "1 févr. 2020 à 13:14:15"
    let expectedMediumStyleDateShortStyleTime_fr_CH = "1 févr. 2020 à 13:14"
    let expectedLongStyleDateTime_fr_CH_prefix = "1 février 2020 à 13:14:15 "
    let expectedShortStyleTimeNoDate_fr_CH = "13:14"
    
    let expectedGetShortDate_fr_CH = "01.02.2020"
    let expectedGetDayMonthAndYear_fr_CH = "sam. 01 févr. 2020"
    let expectedGetFullDateFor_fr_CH = "sam. 01 févr. 2020 à 13:14"
    let expectedGetYearFor_fr_CH = "2020"
    
    let expectedRelativeMediumDateYesterday_fr_CH = "hier"
    let expectedRelativeMediumDateThisYear_fr_CH = " 01 janv."
    let expectedRelativeMediumDateLastCalendarYear_fr_CH = " 31 déc. "
    let expectedRelativeMediumDateMoreThanAYearAgo_fr_CH = "ven. 01 févr. 2019"
    let expectedRelativeMediumDateAndShortTimeYesterday_fr_CH: String = {
        if #available(iOS 17.4, *) {
            return "hier à "
        }
        else {
            return "hier, "
        }
    }()
    
    let expectedRelativeMediumDateAndShortTimeThisYear_fr_CH = " 01 janv. à 13:14"
    let expectedRelativeMediumDateAndShortTimeLastCalendarYear_start_fr_CH = " 31 déc. "
    let expectedRelativeMediumDateAndShortTimeLastCalendarYear_end_fr_CH = " à 22:23"
    let expectedRelativeMediumDateAndShortTimeMoreThanAYearAgo_fr_CH = "ven. 01 févr. 2019 à 13:14"
    let expectedRelativeTimeTodayAndMediumDateOtherwiseToday_fr_CH = "13:14"
    let expectedRelativeTimeTodayAndMediumDateOtherwiseYesterday_fr_CH = "hier"

    let expectedRelativeLongStyleDateShortStyleTimeTomorrow_fr_CH: String = {
        if #available(iOS 17.4, *) {
            return "demain à 02:03"
        }
        else if #available(iOS 17.0, *) {
            return "demain, 02:03"
        }
        else {
            return "demain à 02:03"
        }
    }()
    
    let expectedRelativeLongStyleDateShortStyleTimeToday_fr_CH: String = {
        if #available(iOS 17.4, *) {
            return "aujourd’hui à 13:14"
        }
        else if #available(iOS 17.0, *) {
            return "aujourd’hui, 13:14"
        }
        else {
            return "aujourd’hui à 13:14"
        }
    }()
    
    let expectedAccessibilityDateTime_fr_CH = "1 février 2020 à 13:14"
    let expectedAccessibilityRelativeDayTime_fr_CH: String = {
        if #available(iOS 17.4, *) {
            return "1 février 2020 à 13:14"
        }
        else if #available(iOS 17.0, *) {
            return "1 février 2020, 13:14"
        }
        else {
            return "1 février 2020 à 13:14"
        }
    }()
    
    // MARK: - Test formats provided by the system
    
    func testShortStyleDateTime() {
        let actual: String = DateFormatter.shortStyleDateTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedShortStyleDateTime_fr_CH)
    }
    
    func testShortStyleDateTimeSeconds() {
        let actual: String = DateFormatter.shortStyleDateTimeSeconds(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedShortStyleDateTimeSeconds_fr_CH)
    }
    
    func testMediumStyleDateTime() {
        let actual: String = DateFormatter.mediumStyleDateTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedMediumStyleDateTime_fr_CH)
    }
    
    func testMediumStyleDateShortStyleTime() {
        let actual = DateFormatter.mediumStyleDateShortStyleTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedMediumStyleDateShortStyleTime_fr_CH)
    }
    
    func testLongStyleDateTime() {
        let actual: String = DateFormatter.longStyleDateTime(DateFormatterTests.testDate)
        
        // As time zone suffix changes between system time zones we can only test for the prefix
        XCTAssertTrue(actual.hasPrefix(expectedLongStyleDateTime_fr_CH_prefix))
    }
    
    func testShortStyleTimeNoDate() {
        let actual = DateFormatter.shortStyleTimeNoDate(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedShortStyleTimeNoDate_fr_CH)
    }
    
    func testRelativeLongStyleDateShortStyleTimeTomorrow() {
        let actual = DateFormatter.relativeLongStyleDateShortStyleTime(DateFormatterTests.testDateTomorrowAt20304)
        
        XCTAssertEqual(actual, expectedRelativeLongStyleDateShortStyleTimeTomorrow_fr_CH)
    }
    
    func testRelativeLongStyleDateShortStyleTimeToday() {
        let actual = DateFormatter.relativeLongStyleDateShortStyleTime(DateFormatterTests.testDateTodayAt131415)
        
        XCTAssertEqual(actual, expectedRelativeLongStyleDateShortStyleTimeToday_fr_CH)
    }
    
    // MARK: - Test custom formats
    
    func testGetShortDate() {
        let actual = DateFormatter.getShortDate(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetShortDate_fr_CH)
    }
    
    func testGetDayMonthAndYear() {
        let actual = DateFormatter.getDayMonthAndYear(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetDayMonthAndYear_fr_CH)
    }
    
    func testGetFullDateFor() {
        let actual = DateFormatter.getFullDate(for: DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetFullDateFor_fr_CH)
    }
    
    func testGetFullDateForWithReinitalization() {
        DateFormatter.forceReinitialize()
        DateFormatter.locale = Locale(identifier: localeIdentifier)
        
        let actual = DateFormatter.getFullDate(for: DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetFullDateFor_fr_CH)
    }
    
    func testGetYear() {
        let actual = DateFormatter.getYear(for: DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetYearFor_fr_CH)
    }
    
    // MARK: - Test to `Date` converter
    
    func testGetDateFromDayMonthAndYearDateStringWithReinitalization() throws {
        DateFormatter.forceReinitialize()
        DateFormatter.locale = Locale(identifier: localeIdentifier)
        
        let actual = try XCTUnwrap(DateFormatter.getDateFromDayMonthAndYearDateString(expectedGetDayMonthAndYear_fr_CH))
        
        let comparisonResult = Calendar.current.compare(actual, to: DateFormatterTests.testDate, toGranularity: .day)
        
        XCTAssertEqual(comparisonResult, .orderedSame, "The dates are not equal up to the day")
    }
    
    func testGetDateFromFullDateStringWithReinitalization() throws {
        DateFormatter.forceReinitialize()
        DateFormatter.locale = Locale(identifier: localeIdentifier)
        
        let actual = try XCTUnwrap(DateFormatter.getDateFromFullDateString(expectedGetFullDateFor_fr_CH))
        
        let comparisonResult = Calendar.current.compare(actual, to: DateFormatterTests.testDate, toGranularity: .minute)
        
        XCTAssertEqual(comparisonResult, .orderedSame, "The dates are not equal up to the second")
    }
    
    // MARK: - Test relative custom formats
    
    func testRelativeMediumDateYesterday() throws {
        let twentyFourHoursAgo = Date(timeIntervalSinceNow: -(60 * 60 * 24))
        
        let actual = DateFormatter.relativeMediumDate(for: twentyFourHoursAgo)
        
        XCTAssertEqual(actual, expectedRelativeMediumDateYesterday_fr_CH)
    }
    
    func testRelativeMediumDateThisYear() throws {
        try XCTSkipIf(
            DateFormatterTests.todayIsInTheFirstSevenDaysOfTheYear,
            "Because the date is relative and based on the current year this will not work properly if today is in the first week of the year"
        )
        
        let expected =
            "\(DateFormatterTests.formattedShortWeekday(DateFormatterTests.testDateThisYear, localeIdentifier))\(expectedRelativeMediumDateThisYear_fr_CH)"
        
        let actual = DateFormatter.relativeMediumDate(for: DateFormatterTests.testDateThisYear)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testRelativeMediumDateLastCalendarYear() throws {
        try XCTSkipIf(
            DateFormatterTests.todayIsInTheFirstSevenDaysOfTheYear,
            "Because the date is relative and based on the current year this will not work properly if today is in the first week of the year"
        )
        
        let expected =
            "\(DateFormatterTests.formattedShortWeekday(DateFormatterTests.testDateLastCalendarYear, localeIdentifier))\(expectedRelativeMediumDateLastCalendarYear_fr_CH)\(DateFormatterTests.formattedFullYear(DateFormatterTests.testDateLastCalendarYear, localeIdentifier))"

        let actual = DateFormatter.relativeMediumDate(for: DateFormatterTests.testDateLastCalendarYear)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testRelativeMediumDateMoreThanAYearAgo() {
        let actual = DateFormatter.relativeMediumDate(for: DateFormatterTests.testDateMoreThanAYearAgo)
        
        XCTAssertEqual(actual, expectedRelativeMediumDateMoreThanAYearAgo_fr_CH)
    }
    
    func testRelativeMediumDateAndShortTimeYesterday() throws {
        let twentyFourHoursAgo = Date(timeIntervalSinceNow: -(60 * 60 * 24))
        
        let expected =
            "\(expectedRelativeMediumDateAndShortTimeYesterday_fr_CH)\(DateFormatter.shortStyleTimeNoDate(twentyFourHoursAgo))"
        
        let actual = DateFormatter.relativeMediumDateAndShortTime(for: twentyFourHoursAgo)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testRelativeMediumDateAndShortTimeThisYearWithReset() throws {
        try XCTSkipIf(
            DateFormatterTests.todayIsInTheFirstSevenDaysOfTheYear,
            "Because the date is relative and based on the current year this will not work properly if today is in the first week of the year"
        )
        
        let expected =
            "\(DateFormatterTests.formattedShortWeekday(DateFormatterTests.testDateThisYear, localeIdentifier))\(expectedRelativeMediumDateAndShortTimeThisYear_fr_CH)"

        DateFormatter.forceReinitialize()
        DateFormatter.locale = Locale(identifier: localeIdentifier)
        
        let actual = DateFormatter.relativeMediumDateAndShortTime(for: DateFormatterTests.testDateThisYear)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testRelativeMediumDateAndShortTimeLastCalendarYear() throws {
        try XCTSkipIf(
            DateFormatterTests.todayIsInTheFirstSevenDaysOfTheYear,
            "Because the date is relative and based on the current year this will not work properly if today is in the first week of the year"
        )
        
        let expected =
            "\(DateFormatterTests.formattedShortWeekday(DateFormatterTests.testDateLastCalendarYear, localeIdentifier))\(expectedRelativeMediumDateAndShortTimeLastCalendarYear_start_fr_CH)\(DateFormatterTests.formattedFullYear(DateFormatterTests.testDateLastCalendarYear, localeIdentifier))\(expectedRelativeMediumDateAndShortTimeLastCalendarYear_end_fr_CH)"

        let actual = DateFormatter.relativeMediumDateAndShortTime(for: DateFormatterTests.testDateLastCalendarYear)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testRelativeMediumDateAndShortTimeMoreThanAYearAgo() {
        let actual = DateFormatter.relativeMediumDateAndShortTime(for: DateFormatterTests.testDateMoreThanAYearAgo)
        
        XCTAssertEqual(actual, expectedRelativeMediumDateAndShortTimeMoreThanAYearAgo_fr_CH)
    }
    
    func testRelativeTimeTodayAndMediumDateOtherwiseToday() {
        let actual = DateFormatter
            .relativeTimeTodayAndMediumDateOtherwise(for: DateFormatterTests.testDateTodayAt131415)
        
        XCTAssertEqual(actual, expectedRelativeTimeTodayAndMediumDateOtherwiseToday_fr_CH)
    }
    
    func testRelativeTimeTodayAndMediumDateOtherwiseYesterday() throws {
        let twentyFourHoursAgo = Date(timeIntervalSinceNow: -(60 * 60 * 24))
        
        let actual = DateFormatter.relativeTimeTodayAndMediumDateOtherwise(for: twentyFourHoursAgo)
        
        XCTAssertEqual(actual, expectedRelativeTimeTodayAndMediumDateOtherwiseYesterday_fr_CH)
    }
    
    // MARK: - Test accessibility formats
    
    func testAccessibilityDateTime() {
        let actual = DateFormatter.accessibilityDateTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedAccessibilityDateTime_fr_CH)
    }
    
    func testAccessibilityRelativeDayTime() {
        let actual = DateFormatter.accessibilityRelativeDayTime(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedAccessibilityRelativeDayTime_fr_CH)
    }
}
