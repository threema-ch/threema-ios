//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2023 Threema GmbH
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

#import "ErrorHandler.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

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

+ (void)abortWithError:(NSError *)error {
    // Could called from background thread, since we have Core Data child context
    dispatch_async(dispatch_get_main_queue(), ^{
        [self abortWithError:error additionalText:nil];
    });
}

+ (void)abortWithError:(NSError *)error additionalText:(NSString*)additionalText {
    DDLogError(@"Aborting: unresolved error %@, %@", error, [error userInfo]);
    
    NSString *localizedMessage = [NSString stringWithFormat:@"%@ (%@ %ld)", [error localizedDescription], error.domain, (long)error.code];
    
    if (additionalText != nil) {
        localizedMessage = [NSString stringWithFormat:@"%@\n\n%@", localizedMessage, additionalText];
    }
    
    [ErrorHandler abortWithTitle:[BundleUtil localizedStringForKey:@"error_abort"] message:localizedMessage];
}

+ (void)abortWithTitle:(NSString *)title message:(NSString*)message {
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
