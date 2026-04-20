#import "JsonUtil.h"
#import "ThreemaError.h"

@implementation JsonUtil

+ (NSData *)serializeJsonFrom:(id)object error:(NSError *)error {
    NSData *jsonData = nil;
    @try {
        jsonData = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
    }
    @catch (NSException *exception) {
        error = [ThreemaError threemaError: [exception description]];
    }
    return jsonData;
}


@end
