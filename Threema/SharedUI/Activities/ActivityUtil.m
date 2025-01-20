//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2025 Threema GmbH
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

@implementation ActivityUtil


+ (UIActivityViewController *)activityViewControllerForMessage:(BaseMessage *)message withView:(UIView *)view andBarButtonItem:(UIBarButtonItem *)barButtonItem {
    MessageActivityItem *item = [MessageActivityItem activityItemFor: message];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[item] applicationActivities:nil];
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
