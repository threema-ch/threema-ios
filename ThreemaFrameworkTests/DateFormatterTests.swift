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

class DateFormatterTests: XCTestCase {
    
    // 1.2.2020 13:14:15.00016 in the current system time zone
    static var testDate: Date {
        var dateComponents = DateComponents()
        dateComponents.day = 1
        dateComponents.month = 2
        dateComponents.year = 2020
        
        dateComponents.hour = 13
        dateComponents.minute = 14
        dateComponents.second = 15
        dateComponents.nanosecond = 999_000_000
        
        dateComponents.timeZone = Calendar.current.timeZone

        return Calendar.current.date(from: dateComponents)!
    }
    
    // Test dates for relative formatting
    
    // xx.xx.xxxx 2:03:04.00005 in the current system time zone
    // xx.xx.xxxx is tomorrow
    static var testDateTomorrowAt20304: Date {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.day = dateComponents.day! + 1

        dateComponents.hour = 2
        dateComponents.minute = 3
        dateComponents.second = 4
        dateComponents.nanosecond = 5
        
        dateComponents.timeZone = Calendar.current.timeZone
        
        return Calendar.current.date(from: dateComponents)!
    }
    
    // xx.xx.xxxx 13:14:15.00016 in the current system time zone
    // xx.xx.xxxx is today
    static var testDateTodayAt131415: Date {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        
        dateComponents.hour = 13
        dateComponents.minute = 14
        dateComponents.second = 15
        dateComponents.nanosecond = 16
        
        dateComponents.timeZone = Calendar.current.timeZone
        
        return Calendar.current.date(from: dateComponents)!
    }
    
    // 1.1.xxxx 13:14:15.00016 GMT+1
    // xxxx is the current year
    static var testDateThisYear: Date {
        var dateComponents = Calendar.current.dateComponents([.year], from: Date())
        dateComponents.day = 1
        dateComponents.month = 1
        
        dateComponents.hour = 13
        dateComponents.minute = 14
        dateComponents.second = 15
        dateComponents.nanosecond = 16
        
        dateComponents.timeZone = TimeZone(abbreviation: "GMT+1")
        
        return Calendar.current.date(from: dateComponents)!
    }
    
    // 31.12.xxxx 22:23:24.00025 GMT+1
    // xxxx is last year
    static var testDateLastCalendarYear: Date {
        var dateComponents = Calendar.current.dateComponents([.year], from: Date())
        dateComponents.day = 31
        dateComponents.month = 12
        dateComponents.year! -= 1
        
        dateComponents.hour = 22
        dateComponents.minute = 23
        dateComponents.second = 24
        dateComponents.nanosecond = 25
        
        dateComponents.timeZone = TimeZone(abbreviation: "GMT+1")
        
        return Calendar.current.date(from: dateComponents)!
    }
    
    // Detect if today is in the first seven days of the year
    static var todayIsInTheFirstSevenDaysOfTheYear: Bool {
        var january1stComponents = Calendar.current.dateComponents([.year], from: Date())
        january1stComponents.day = 1
        january1stComponents.month = 1
        
        january1stComponents.hour = 0
        january1stComponents.minute = 0
        january1stComponents.second = 0
        january1stComponents.nanosecond = 0
        
        january1stComponents.timeZone = TimeZone(abbreviation: "GMT+1")
        
        var january6thComponents = Calendar.current.dateComponents([.year], from: Date())
        january6thComponents.day = 6
        january6thComponents.month = 1
        
        january6thComponents.hour = 23
        january6thComponents.minute = 59
        january6thComponents.second = 59
        january6thComponents.nanosecond = 999
        
        january6thComponents.timeZone = TimeZone(abbreviation: "GMT+1")
        
        return Calendar.current.date(from: january1stComponents)! < Date() &&
            Date() < Calendar.current.date(from: january6thComponents)!
    }
    
    // Helper to format expected strings from relative formatting
    static func formattedShortWeekday(_ date: Date, _ identifier: String) -> String {
        let formatter = Foundation.DateFormatter()
        formatter.locale = Locale(identifier: identifier)
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    // Helper to format expected strings from relative formatting
    static func formattedFullYear(_ date: Date, _ identifier: String) -> String {
        let formatter = Foundation.DateFormatter()
        formatter.locale = Locale(identifier: identifier)
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
    
    // 1.2.2019 13:14:15.00016 GMT+1
    static var testDateMoreThanAYearAgo: Date {
        var dateComponents = DateComponents()
        dateComponents.day = 1
        dateComponents.month = 2
        dateComponents.year = 2019
        
        dateComponents.hour = 13
        dateComponents.minute = 14
        dateComponents.second = 15
        dateComponents.nanosecond = 16
        
        dateComponents.timeZone = TimeZone(abbreviation: "GMT+1")
        
        return Calendar.current.date(from: dateComponents)!
    }
    
    func testGetDateForFilename() {
        let expected = "20200201-131415-999"
        let actual = DateFormatter.getDateForFilename(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testGetDateForExport() {
        let expected = "2020-02-01_13-14-15"
        let actual = DateFormatter.getDateForExport(DateFormatterTests.testDate)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testTimeIntervalFormattedSeconds() {
        let expected = "00:59"
        
        let inputSeconds: TimeInterval = 59
        let actual = DateFormatter.timeFormatted(inputSeconds)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testTimeIntervalFormattedMinutes() {
        let expected = "01:11"
        
        let inputSeconds: TimeInterval = 71
        let actual = DateFormatter.timeFormatted(inputSeconds)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testTimeIntervalFormattedHour() {
        let expected = "02:11:03"
        
        let inputSeconds: TimeInterval = 7863
        let actual = DateFormatter.timeFormatted(inputSeconds)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testTimeIntervalFormattedHourAndSeconds() {
        let expected = "02:11:03"
        
        let inputSeconds: TimeInterval = 7863
        let actual = DateFormatter.timeFormatted(inputSeconds)
        
        XCTAssertEqual(actual, expected)
        
        // This tests if the static formatter is correctly reset to min & sec if the time interval is below 1h
        
        let expected2 = "00:59"
        
        let inputSeconds2: TimeInterval = 59
        let actual2 = DateFormatter.timeFormatted(inputSeconds2)
        
        XCTAssertEqual(actual2, expected2)
    }

    func testTimeFormattedSeconds() {
        let expected = "00:59"
        
        let inputSeconds = 59
        let actual = DateFormatter.timeFormatted(inputSeconds)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testTimeFormattedMinutes() {
        let expected = "01:11"
        
        let inputSeconds = 71
        let actual = DateFormatter.timeFormatted(inputSeconds)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testTimeFormattedHour() {
        let expected = "02:11:03"
        
        let inputSeconds = 7863
        let actual = DateFormatter.timeFormatted(inputSeconds)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testMaybeNegativeTimeFormattedHour() {
        let expected = "-02:11:03"
        
        let inputSeconds = -7863
        let actual = DateFormatter.maybeNegativeTimeFormatted(inputSeconds)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testMaybeNegativeTimeFormattedMinute() {
        let expected = "-01:23"
        
        let inputSeconds = -83
        let actual = DateFormatter.maybeNegativeTimeFormatted(inputSeconds)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testMaybeNegativeTimeFormattedSeconds() {
        let expected = "-00:33"
        
        let inputSeconds = -33
        let actual = DateFormatter.maybeNegativeTimeFormatted(inputSeconds)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testTotalSeconds() {
        let expected = 541
        
        let inputString = "09:01"
        let actual = DateFormatter.totalSeconds(inputString)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testTotalSecondsNoLeadingZero() {
        let expected = 482
        
        let inputString = "8:02"
        let actual = DateFormatter.totalSeconds(inputString)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testTotalSecondsWithHours() {
        let expected = 8411
        
        let inputString = "02:20:11"
        let actual = DateFormatter.totalSeconds(inputString)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testTotalSecondsWithZeroHours() {
        let expected = 1211
        
        let inputString = "00:20:11"
        let actual = DateFormatter.totalSeconds(inputString)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testTotalSecondsWithCharacterInput() {
        let expected = 3611
        
        let inputString = "01:f:11"
        let actual = DateFormatter.totalSeconds(inputString)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testTotalSecondsWithWnlySecondsInput() {
        let expected = 51
        
        let inputString = "51"
        let actual = DateFormatter.totalSeconds(inputString)
        
        XCTAssertEqual(actual, expected)
    }
    
    func testReversingOfTimeFormattedWithTotalSecondsShort() {
        let expected = 120
        
        let actual = DateFormatter.totalSeconds(DateFormatter.timeFormatted(expected))
        
        XCTAssertEqual(actual, expected)
    }
    
    func testReversingOfTimeFormattedWithTotalSecondsLong() {
        let expected = 53294
        
        let actual = DateFormatter.totalSeconds(DateFormatter.timeFormatted(expected))
        
        XCTAssertEqual(actual, expected)
    }
    
    func testReversingOfTotalSecondsWithTimeFormattedShort() {
        let expected = "04:58"
        
        let actual = DateFormatter.timeFormatted(DateFormatter.totalSeconds(expected))
        
        XCTAssertEqual(actual, expected)
    }
    
    func testReversingOfTotalSecondsWithTimeFormattedShortNoLeadingZero() {
        let input = "4:58"
        let expected = "04:58"
        
        let actual = DateFormatter.timeFormatted(DateFormatter.totalSeconds(input))
        
        XCTAssertEqual(actual, expected)
    }
    
    func testReversingOfTotalSecondsWithTimeFormattedLong() {
        let expected = "13:04:58"
        
        let actual = DateFormatter.timeFormatted(DateFormatter.totalSeconds(expected))
        
        XCTAssertEqual(actual, expected)
    }
    
    // MARK: - Test to `Date` converter
    
    func testGetDateFromDayMonthAndYearDateStringWithEmptyString() {
        let result = DateFormatter.getDateFromDayMonthAndYearDateString("")
        
        XCTAssertNil(result)
    }
    
    func testGetDateFromFullDateStringWithEmptyString() {
        let result = DateFormatter.getDateFromFullDateString("")
                
        XCTAssertNil(result)
    }
}
