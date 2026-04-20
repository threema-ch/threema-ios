#import <XCTest/XCTest.h>

@interface MediaConverterTest : XCTestCase

@end

@implementation MediaConverterTest

- (void)testImageWithCGImageNil {
    XCTAssertNil([UIImage imageWithCGImage:nil],
                 @"This shows undefined behavior. We have to check for `nil` inputs in external `UIImage+Resize`.");
}

@end
