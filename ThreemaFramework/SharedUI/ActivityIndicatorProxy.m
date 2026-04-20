#import "ActivityIndicatorProxy.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

static id wiredActivityIndicator;

@implementation ActivityIndicatorProxy

+ (void)wireActivityIndicator:(id)activityIndicator {
    if ([activityIndicator respondsToSelector:@selector(startActivity)] == NO) {
        DDLogError(@"activityIndicator is required to implement 'startActivity'");
        return;
    }

    if ([activityIndicator respondsToSelector:@selector(stopActivity)] == NO) {
        DDLogError(@"activityIndicator is required to implement 'stopActivity'");
        return;
    }

    wiredActivityIndicator = activityIndicator;
}


+ (void)startActivity {
    if (wiredActivityIndicator) {
        [wiredActivityIndicator startActivity];
    }
}

+ (void)stopActivity {
    if (wiredActivityIndicator) {
        [wiredActivityIndicator stopActivity];
    }
}

@end
