//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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

#import "ShareTextActivityItemProvider.h"
#import "MyIdentityStore.h"
#import "BundleUtil.h"

@implementation ShareTextActivityItemProvider

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType {
    if ([activityType isEqualToString:UIActivityTypePostToFacebook]) {
        return [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"invite_facebook_text"], [[MyIdentityStore sharedMyIdentityStore] identity]];
    }
    else if ([activityType isEqualToString:UIActivityTypePostToTwitter]) {
        return [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"invite_twitter_text"], [[MyIdentityStore sharedMyIdentityStore] identity]];
    }
    else if ([activityType isEqualToString:UIActivityTypeMail]) {
        return [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"invite_email_body"], [[MyIdentityStore sharedMyIdentityStore] identity]];
    }
    else if ([activityType isEqualToString:UIActivityTypeMessage]) {
        return [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"invite_sms_body"], [[MyIdentityStore sharedMyIdentityStore] identity]];
    }
    
    return [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"invite_facebook_text"], [[MyIdentityStore sharedMyIdentityStore] identity]];
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(UIActivityType)activityType {
    if ([activityType isEqualToString:UIActivityTypeMail]) {
        return [BundleUtil localizedStringForKey:@"invite_email_subject"];
    }
    return nil;
}

@end

