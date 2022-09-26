//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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

#import "ActivityUtil.h"
#import "MessageActivityItem.h"
#import "TTOpenInAppActivity.h"
#import "ForwardTextActivity.h"
#import "ForwardURLActivity.h"
#import "QRCodeActivity.h"

@implementation ActivityUtil

+ (NSArray *)defaultApplicationActivities {
    NSArray *applicationActivities = @[
                                       [[ForwardTextActivity alloc] init],
                                       [[ForwardURLActivity alloc] init],
                                       [[QRCodeActivity alloc] init]
                                       ];
    return applicationActivities;
}

+ (UIActivityViewController *)activityViewControllerForMessage:(BaseMessage *)message withView:(UIView *)view andRect:(CGRect)rect {
    TTOpenInAppActivity *openInAppActivity = [[TTOpenInAppActivity alloc] initWithView:view andRect:rect];
    
    return [self activityViewControllerForMessage:message withTTOpenInAppActivity:openInAppActivity];
}

+ (UIActivityViewController *)activityViewControllerForMessage:(BaseMessage *)message withView:(UIView *)view andBarButtonItem:(UIBarButtonItem *)barButtonItem {
    
    TTOpenInAppActivity *openInAppActivity = [[TTOpenInAppActivity alloc] initWithView:view andBarButtonItem:barButtonItem];
    
    return [self activityViewControllerForMessage:message withTTOpenInAppActivity:openInAppActivity];
}

+ (UIActivityViewController *)activityViewControllerForMessage:(BaseMessage *)message withTTOpenInAppActivity:(TTOpenInAppActivity *)openInAppActivity {
    MessageActivityItem *item = [MessageActivityItem activityItemFor: message];
    
    NSMutableArray *applicationActivities = [NSMutableArray arrayWithArray:[ActivityUtil defaultApplicationActivities]];
    [applicationActivities addObject:openInAppActivity];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[item] applicationActivities:applicationActivities];
    openInAppActivity.superViewController = activityViewController;
    activityViewController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        
        NSURL *tmpFileUrl = [item getURL];
        if (tmpFileUrl) {
            [[NSFileManager defaultManager] removeItemAtURL:tmpFileUrl error:nil];
        }
    };
    
    return activityViewController;

}

+ (UIActivityViewController *)activityViewControllerWithActivityItems:(NSArray *)activityItems applicationActivities:(NSArray *)applicationActivities {
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:applicationActivities];
    return activityViewController;
}


@end
