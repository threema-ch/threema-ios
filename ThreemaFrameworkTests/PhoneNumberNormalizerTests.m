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
