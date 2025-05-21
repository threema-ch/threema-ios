//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2025 Threema GmbH
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

#import "InviteController.h"
#import "AppDelegate.h"
#import <Social/Social.h>
#import "ShareTextActivityItemProvider.h"
#import "ActivityUtil.h"
#import "MyIdentityStore.h"
#import "BundleUtil.h"

@implementation InviteController {
}

static InviteController *currentInviteController;

- (void)invite {
    ShareTextActivityItemProvider *shareText = [[ShareTextActivityItemProvider alloc] initWithPlaceholderItem:[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"invite_facebook_text"], TargetManagerObjc.appName, TargetManagerObjc.localizedAppName,  [[MyIdentityStore sharedMyIdentityStore] identity]]];
    NSMutableArray *activityItems = [[NSMutableArray alloc] initWithArray:@[shareText]];

    UIActivityViewController* activityViewController = [ActivityUtil activityViewControllerWithActivityItems:activityItems applicationActivities:nil];
    if (SYSTEM_IS_IPAD) {
        activityViewController.popoverPresentationController.sourceView = self.parentViewController.view;
        activityViewController.popoverPresentationController.sourceRect = _rect;
    }

    [self.shareViewController presentViewController:activityViewController animated:YES completion:nil];
}

- (void)presentMailComposer {
    MFMailComposeViewController *mailComposer = [[MFMailComposeViewController alloc] init];
    [mailComposer setSubject:[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"invite_email_subject"], TargetManagerObjc.appName]];
    [mailComposer setMessageBody:[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"invite_email_body"], TargetManagerObjc.appName, TargetManagerObjc.localizedAppName, [[MyIdentityStore sharedMyIdentityStore] identity], TargetManagerObjc.appName] isHTML:NO];
    mailComposer.mailComposeDelegate = self;
    [self.parentViewController presentViewController:mailComposer animated:YES completion:nil];
    
    /* Trick to avoid getting deallocated (since delegates are not retained) */
    currentInviteController = self;
}

- (void)presentMessageComposer {
    MFMessageComposeViewController *smsComposer = [[MFMessageComposeViewController alloc] init];
    [smsComposer setBody:[NSString stringWithFormat:[NSString stringWithFormat:[BundleUtil localizedStringForKey:@"invite_sms_body"],TargetManagerObjc.appName, TargetManagerObjc.localizedAppName,  [[MyIdentityStore sharedMyIdentityStore] identity]]]];
    smsComposer.messageComposeDelegate = self;
    [self.parentViewController presentViewController:smsComposer animated:YES completion:nil];
    
    /* Trick to avoid getting deallocated (since delegates are not retained) */
    currentInviteController = self;
}

#pragma mark - Mail composer delegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [self.parentViewController dismissViewControllerAnimated:YES completion:nil];
    currentInviteController = nil;
}

#pragma mark - Message composer delegate

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result {
    [self.parentViewController dismissViewControllerAnimated:YES completion:nil];
    currentInviteController = nil;
}

@end
