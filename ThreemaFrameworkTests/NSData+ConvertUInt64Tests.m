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

#import <XCTest/XCTest.h>
#import "NSData+ConvertUInt64.h"

@interface NSData_ConvertUInt64Tests : XCTestCase
@end

@implementation NSData_ConvertUInt64Tests {
    UInt8 _testBytes[2][8];
    NSString *_expectedUInt64[2];
}

- (void)setUp {
    [super setUp];
    
    memcpy(_testBytes, (UInt8[2][8]){{0x01,0x00,0x01,0x01,0x01,0x01,0x01,0xfe},{0x2e,0xee,0x11,0xd4,0xfd,0xf8,0xf7,0xa3}}, 16);
    _expectedUInt64[0] = @"18302911464433844225";
    _expectedUInt64[1] = @"11815185916498144814";
}

- (void)testConvertBytesToUInt64AndBack {
    for (int run = 0; run < sizeof(_testBytes)/8; run++) {
        NSData *data = [[NSData alloc] initWithBytes:_testBytes[run] length:8];
        
        UInt64 resultUInt64 = [data convertUInt64];

        NSString *stringResultUint64 = [NSString stringWithFormat:@"%"PRIu64, resultUInt64];
        XCTAssertTrue([_expectedUInt64[run] isEqual:stringResultUint64]);

        NSData *resultData = [NSData convertBytes:resultUInt64];
        
        const uint8_t *bytesResultData = [resultData bytes];
        for (int i = 0; i < 8; i++) {
            XCTAssertEqual(bytesResultData[i], _testBytes[run][i]);
        }
    }
}

- (void)testConvertBytesToUInt64 {
    for (int run = 0; run < sizeof(_testBytes)/8; run++) {
        UInt64 result = 0;
        for (int i = 7; i >= 0; i--)
        {
            result = result << 8 | (UInt64)_testBytes[run][i];
        }
        NSString *stringResult = [NSString stringWithFormat:@"%"PRIu64, result];
        XCTAssertTrue([_expectedUInt64[run] isEqual:stringResult]);
    }
}

- (void)testConvertStringToUInt64 {
    for (int run = 0; run < sizeof(_testBytes)/8; run++) {
        NSScanner *scanner = [NSScanner scannerWithString:_expectedUInt64[run]];
        unsigned long long result = 0;
        [scanner scanUnsignedLongLong:&result];

        NSString *stringResult = [NSString stringWithFormat:@"%"PRIu64, result];
        XCTAssertTrue([_expectedUInt64[run] isEqualToString:stringResult]);
    }
}

@end
