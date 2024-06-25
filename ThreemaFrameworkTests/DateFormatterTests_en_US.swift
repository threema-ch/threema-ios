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

class DateFormatterTests_en_US: XCTestCase {
    
    let localeIdentifier = "en_US"
    
    override func setUp() {
        DateFormatter.locale = Locale(identifier: localeIdentifier)
    }
    
    // Expected date strings
    let expectedShortStyleDateTime_en_US: String = {
        if #available(iOS 17.0, *) {
            return "2/1/20, 1:14 PM"
        }
        else {
            return "2/1/20, 1:14 PM"
        }
    }()

    let expectedShortStyleDateTimeSeconds_en_US: String = {
        if #available(iOS 17.0, *) {
            return "2/1/20, 1:14:15 PM"
        }
        else {
            return "2/1/20, 1:14:15 PM"
        }
    }()
    
    let expectedMediumStyleDateTime_en_US: String = {
        if #available(iOS 17.0, *) {
            return "Feb 1, 2020 at 1:14:15 PM"
        }
        else {
            return "Feb 1, 2020 at 1:14:15 PM"
        }
    }()
    
    let expectedMediumStyleDateShortStyleTime_en_US: String = {
        if #available(iOS 17.0, *) {
            return "Feb 1, 2020 at 1:14 PM"
        }
        else {
            return "Feb 1, 2020 at 1:14 PM"
        }
    }()
    
    let expectedLongStyleDateTime_en_US_prefix: String = {
        if #available(iOS 17.0, *) {
            return "February 1, 2020 at 1:14:15 PM"
        }
        else {
            return "February 1, 2020 at 1:14:15 PM"
        }
    }()
    
    let expectedShortStyleTimeNoDate_en_US: String = {
        if #available(iOS 17.0, *) {
            return "1:14 PM"
        }
        else {
            return "1:14 PM"
        }
    }()
    
    let expectedGetShortDate_en_US = "2/1/2020"
    let expectedGetDayMonthAndYear_en_US = "Sat, Feb 01, 2020"
    let expectedGetFullDateFor_en_US: String = {
        if #available(iOS 17.0, *) {
            return "Sat, Feb 01, 2020 at 1:14 PM"
        }
        else if #available(iOS 16.0, *) {
            return "Sat, Feb 01, 2020 at 1:14 PM"
        }
        else {
            return "Sat, Feb 01, 2020, 1:14 PM"
        }
    }()

    let expectedGetYearFor_en_US = "2020"
    
    let expectedRelativeMediumDateYesterday_en_US = "Yesterday"
    let expectedRelativeMediumDateThisYear_en_US = ", Jan 01"
    let expectedRelativeMediumDateLastCalendarYear_en_US = ", Dec 31, "
    let expectedRelativeMediumDateMoreThanAYearAgo_en_US = "Fri, Feb 01, 2019"
    let expectedRelativeMediumDateAndShortTimeYesterday_en_US: String = {
        if #available(iOS 17.4, *) {
            return "Yesterday at "
        }
        else {
            return "Yesterday, "
        }
    }()

    let expectedRelativeMediumDateAndShortTimeThisYear_en_US = ", Jan 01 at 1:14 PM"
    let expectedRelativeMediumDateAndShortTimeLastCalendarYear_start_en_US = ", Dec 31, "
    let expectedRelativeMediumDateAndShortTimeLastCalendarYear_end_en_US = " at 10:23 PM"
    let expectedRelativeMediumDateAndShortTimeMoreThanAYearAgo_en_US = "Fri, Feb 01, 2019 at 1:14 PM"

    let expectedRelativeTimeTodayAndMediumDateOtherwiseToday_en_US: String = {
        if #available(iOS 17.0, *) {
            return "1:14 PM"
        }
        else {
            return "1:14 PM"
        }
    }()

    let expectedRelativeTimeTodayAndMediumDateOtherwiseYesterday_en_US = "Yesterday"
    
    let expectedRelativeLongStyleDateShortStyleTimeTomorrow_en_US: String = {
        if #available(iOS 17.4, *) {
            return "Tomorrow at 2:03 AM"
        }
        else if #available(iOS 17.0, *) {
            return "Tomorrow, 2:03 AM"
        }
        else {
            return "Tomorrow at 2:03 AM"
        }
    }()
    
    let expectedRelativeLongStyleDateShortStyleTimeToday_en_US: String = {
        if #available(iOS 17.4, *) {
            return "Today at 1:14 PM"
        }
        else if #available(iOS 17.0, *) {
            return "Today, 1:14 PM"
        }
        else {
            return "Today at 1:14 PM"
        }
    }()
    
    let expectedAccessibilityDateTime_en_US: String = {
        if #available(iOS 17.0, *) {
            return "February 1, 2020 at 1:14 PM"
        }
        else if #available(iOS 16.0, *) {
            return "February 1, 2020 at 1:14 PM"
        }
        else {
            return "February 1, 2020, 1:14 PM"
        }
    }()

    let expectedAccessibilityRelativeDayTime_en_US: String = {
        if #available(iOS 17.4, *) {
            return "February 1, 2020 at 1:14 PM"
        }
        else if #available(iOS 17.0, *) {
            return "February 1, 2020, 1:14 PM"
        }
        else {
            return "February 1, 2020 at 1:14 PM"
        }
    }()
    
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
    
    func testRelativeLongStyleDateShortStyleTimeTomorrow() {
        let actual = DateFormatter.relativeLongStyleDateShortStyleTime(DateFormatterTests.testDateTomorrowAt20304)
        
        XCTAssertEqual(actual, expectedRelativeLongStyleDateShortStyleTimeTomorrow_en_US)
    }
    
    func testRelativeLongStyleDateShortStyleTimeToday() {
        let actual = DateFormatter.relativeLongStyleDateShortStyleTime(DateFormatterTests.testDateTodayAt131415)
        
        XCTAssertEqual(actual, expectedRelativeLongStyleDateShortStyleTimeToday_en_US)
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
    
    func testGetYear() {
        let actual = DateFormatter.getYear(for: DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expectedGetYearFor_en_US)
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
    
    func testRelativeMediumDateThisYear() throws {
        try XCTSkipIf(
            DateFormatterTests.todayIsInTheFirstSevenDaysOfTheYear,
            "Because the date is relative and based on the current year this will not work properly if today is in the first week of the year"
        )
        
        let expected =
            "\(DateFormatterTests.formattedShortWeekday(DateFormatterTests.testDateThisYear, localeIdentifier))\(expectedRelativeMediumDateThisYear_en_US)"
        
        let actual = DateFormatter.relativeMediumDate(for: DateFormatterTests.testDateThisYear)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testRelativeMediumDateLastCalendarYear() throws {
        try XCTSkipIf(
            DateFormatterTests.todayIsInTheFirstSevenDaysOfTheYear,
            "Because the date is relative and based on the current year this will not work properly if today is in the first week of the year"
        )
        
        let expected =
            "\(DateFormatterTests.formattedShortWeekday(DateFormatterTests.testDateLastCalendarYear, localeIdentifier))\(expectedRelativeMediumDateLastCalendarYear_en_US)\(DateFormatterTests.formattedFullYear(DateFormatterTests.testDateLastCalendarYear, localeIdentifier))"
        
        let actual = DateFormatter.relativeMediumDate(for: DateFormatterTests.testDateLastCalendarYear)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testRelativeMediumDateMoreThanAYearAgo() {
        let actual = DateFormatter.relativeMediumDate(for: DateFormatterTests.testDateMoreThanAYearAgo)
        
        XCTAssertEqual(actual, expectedRelativeMediumDateMoreThanAYearAgo_en_US)
    }
    
    func testRelativeMediumDateAndShortTimeYesterday() throws {
        let twentyFourHoursAgo = Date(timeIntervalSinceNow: -(60 * 60 * 24))
        
        let expected =
            "\(expectedRelativeMediumDateAndShortTimeYesterday_en_US)\(DateFormatter.shortStyleTimeNoDate(twentyFourHoursAgo))"
        
        let actual = DateFormatter.relativeMediumDateAndShortTime(for: twentyFourHoursAgo)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testRelativeMediumDateAndShortTimeThisYearWithReset() throws {
        try XCTSkipIf(
            DateFormatterTests.todayIsInTheFirstSevenDaysOfTheYear,
            "Because the date is relative and based on the current year this will not work properly if today is in the first week of the year"
        )
        
        let expected =
            "\(DateFormatterTests.formattedShortWeekday(DateFormatterTests.testDateThisYear, localeIdentifier))\(expectedRelativeMediumDateAndShortTimeThisYear_en_US)"

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
            "\(DateFormatterTests.formattedShortWeekday(DateFormatterTests.testDateLastCalendarYear, localeIdentifier))\(expectedRelativeMediumDateAndShortTimeLastCalendarYear_start_en_US)\(DateFormatterTests.formattedFullYear(DateFormatterTests.testDateLastCalendarYear, localeIdentifier))\(expectedRelativeMediumDateAndShortTimeLastCalendarYear_end_en_US)"

        let actual = DateFormatter.relativeMediumDateAndShortTime(for: DateFormatterTests.testDateLastCalendarYear)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testRelativeMediumDateAndShortTimeMoreThanAYearAgo() {
        let actual = DateFormatter.relativeMediumDateAndShortTime(for: DateFormatterTests.testDateMoreThanAYearAgo)
        
        XCTAssertEqual(actual, expectedRelativeMediumDateAndShortTimeMoreThanAYearAgo_en_US)
    }
    
    func testRelativeTimeTodayAndMediumDateOtherwiseToday() {
        let actual = DateFormatter
            .relativeTimeTodayAndMediumDateOtherwise(for: DateFormatterTests.testDateTodayAt131415)
        
        XCTAssertEqual(actual, expectedRelativeTimeTodayAndMediumDateOtherwiseToday_en_US)
    }
    
    func testRelativeTimeTodayAndMediumDateOtherwiseYesterday() throws {
        let twentyFourHoursAgo = Date(timeIntervalSinceNow: -(60 * 60 * 24))
        
        let actual = DateFormatter.relativeTimeTodayAndMediumDateOtherwise(for: twentyFourHoursAgo)
        
        XCTAssertEqual(actual, expectedRelativeTimeTodayAndMediumDateOtherwiseYesterday_en_US)
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
