#import "ThreemaError.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@implementation ThreemaError

+ (nonnull NSError*)threemaError:(nullable NSString*)message {
    return [self threemaError:message withCode:ThreemaProtocolErrorGeneralError];
}

+ (nonnull NSError*)threemaError:(nullable NSString*)message withCode:(NSInteger)code {
    NSString *errorMessage = message;
    if (errorMessage == nil) {
        errorMessage = @"";
    }
    NSDictionary *userDict = [NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"ThreemaErrorDomain" code:code userInfo:userDict];
}

@end
