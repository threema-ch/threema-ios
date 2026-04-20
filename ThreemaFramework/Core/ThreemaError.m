#import "ThreemaError.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@implementation ThreemaError

+ (NSError*)threemaError:(NSString*)message {
    return [self threemaError:message withCode:ThreemaProtocolErrorGeneralError];
}

+ (NSError*)threemaError:(NSString*)message withCode:(NSInteger)code {
    NSString *errorMessage = message;
    if (errorMessage == nil) {
        errorMessage = @"";
    }
    NSDictionary *userDict = [NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"ThreemaErrorDomain" code:code userInfo:userDict];
}

@end
