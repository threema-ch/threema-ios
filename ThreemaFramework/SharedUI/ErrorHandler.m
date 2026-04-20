#import "ErrorHandler.h"
#import "ThreemaFramework/ThreemaFramework-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
@interface ErrorHandler ()

@end

static ErrorHandler *errorHandler;

@implementation ErrorHandler

+ (instancetype)errorHandler {
    return [[ErrorHandler alloc] init];
}

+ (void)abortWithError:(nonnull NSError *)error {
    // Could called from background thread, since we have Core Data child context
    dispatch_async(dispatch_get_main_queue(), ^{
        [self abortWithError:error additionalText:nil];
    });
}

+ (void)abortWithError:(nonnull NSError *)error additionalText:(nullable NSString *)additionalText {
    DDLogError(@"Aborting: unresolved error %@, %@", error, [error userInfo]);

    // Get first description, because localizedDescription on Swift enum Error cannot be overriden
    NSString *description = [error description];
    if (description == nil) {
        description = [error localizedDescription];
    }

    NSString *localizedMessage = [NSString stringWithFormat:@"%@ (%@ %ld)", description, error.domain, (long)error.code];

    if (additionalText != nil) {
        localizedMessage = [NSString stringWithFormat:@"%@\n\n%@", localizedMessage, additionalText];
    }
    
    [ErrorHandler abortWithTitle:[BundleUtil localizedStringForKey:@"error_abort"] message:localizedMessage];
}

+ (void)abortWithTitle:(nonnull NSString *)title message:(nonnull NSString *)message {
    errorHandler = [ErrorHandler errorHandler];
    
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    if (application == nil) {
        return;
    } else if (application.windows.firstObject.rootViewController == nil) {
        UIViewController *dummyViewController = [[UIViewController alloc] init];
        application.windows.firstObject.rootViewController = dummyViewController;
    }
    
    [UIAlertTemplate showAlertWithOwner:application.windows.firstObject.rootViewController title:title message:message actionOk:^(UIAlertAction * _Nonnull action) {
        exit(0);
    }];
}

@end
