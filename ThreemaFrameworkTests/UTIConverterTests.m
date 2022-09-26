//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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
#import "UTIConverter.h"

@interface UTIConverterTests : XCTestCase

@end

@implementation UTIConverterTests

/// Should get vCard mime type from contacts UTI
- (void)testVCard {
    NSString *result = [UTIConverter mimeTypeFromUTI:UTTYPE_VCARD];
    
    expect(result).to.equal(@"text/vcard");
}

/// Should get stream mime type from contacts UTI
- (void)testStream {
    NSString *result = [UTIConverter mimeTypeFromUTI:@"xyz.unknonw"];
    
    expect(result).to.equal(@"application/octet-stream");
}

/// Should get contacts UTI from vCard mime type
- (void)testUTIContact {
    NSString *result = [UTIConverter utiFromMimeType:@"text/vcard"];
    expect(result).to.equal(UTTYPE_VCARD);
}
@end
