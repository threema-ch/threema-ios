#import <XCTest/XCTest.h>
#import "ThreemaUtilityObjC.h"

@interface UtilsTests : XCTestCase

@end

@implementation UtilsTests

- (void)testEmailValidation {
    XCTAssertFalse([ThreemaUtilityObjC isValidEmail:nil]);
    XCTAssertFalse([ThreemaUtilityObjC isValidEmail:@""]);
    XCTAssertFalse([ThreemaUtilityObjC isValidEmail:@"asfasf"]);
    XCTAssertFalse([ThreemaUtilityObjC isValidEmail:@"a@a"]);
    XCTAssertFalse([ThreemaUtilityObjC isValidEmail:@"@"]);
    XCTAssertFalse([ThreemaUtilityObjC isValidEmail:@"a@a@a"]);

    XCTAssertTrue([ThreemaUtilityObjC isValidEmail:@"test@gaga.com"]);
    XCTAssertTrue([ThreemaUtilityObjC isValidEmail:@"a.b@xx.com"]);
}


@end
