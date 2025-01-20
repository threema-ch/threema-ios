//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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
#import "PhoneNumberNormalizer.h"

@interface PhoneNumberNormalizerTests : XCTestCase

@end

@implementation PhoneNumberNormalizerTests

/// Handle DE numbers
- (void)testNumberDE {
    PhoneNumberNormalizer *normalizer = [PhoneNumberNormalizer sharedInstance];
    
    NSString *number = @"+4916012345678";
    NSString *result = [normalizer phoneNumberToE164:number withDefaultRegion:[PhoneNumberNormalizer userRegion] prettyFormat:&number];
    
    XCTAssert([result isEqualToString:@"4916012345678"]);
}

/// Handle CH numbers
- (void) testNumberCH {
    PhoneNumberNormalizer *normalizer = [PhoneNumberNormalizer sharedInstance];
    
    NSString *number = @"+41791234567";
    NSString *result = [normalizer phoneNumberToE164:number withDefaultRegion:[PhoneNumberNormalizer userRegion] prettyFormat:&number];
    
    XCTAssert([result isEqualToString:@"41791234567"]);
}

@end
