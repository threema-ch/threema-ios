//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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
#import <Expecta/Expecta.h>
#import "ThreemaUtilityObjC.h"

@interface UtilsTests : XCTestCase

@end

@implementation UtilsTests

- (void)testEmailValidation {
    expect([ThreemaUtilityObjC isValidEmail:nil]).to.equal(NO);
    expect([ThreemaUtilityObjC isValidEmail:@""]).to.equal(NO);
    expect([ThreemaUtilityObjC isValidEmail:@"asfasf"]).to.equal(NO);
    expect([ThreemaUtilityObjC isValidEmail:@"a@a"]).to.equal(NO);
    expect([ThreemaUtilityObjC isValidEmail:@"@"]).to.equal(NO);
    expect([ThreemaUtilityObjC isValidEmail:@"a@a@a"]).to.equal(NO);

    expect([ThreemaUtilityObjC isValidEmail:@"test@gaga.com"]).to.equal(YES);
    expect([ThreemaUtilityObjC isValidEmail:@"a.b@xx.com"]).to.equal(YES);
}


@end
