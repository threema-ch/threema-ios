//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
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

#import "RevocationKeyHandler.h"
#import "MyIdentityStore.h"
#import "ServerAPIConnector.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "AppDelegate.h"
#import "BundleUtil.h"

@interface RevocationKeyHandler ()

@property UIViewController *viewController;

@end

@implementation RevocationKeyHandler

-(void)passwordResult:(NSString *)password fromViewController:(UIViewController *)viewController {
    _viewController = viewController;
    
    [MBProgressHUD showHUDAddedTo:_viewController.view animated:YES];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self setPassword:password];
    });
}

- (void)setPassword:(NSString *)password {
    ServerAPIConnector *connector = [[ServerAPIConnector alloc] init];
    MyIdentityStore *store = [MyIdentityStore sharedMyIdentityStore];
    
    [connector setRevocationPassword:password forStore:store onCompletion:^{
        store.revocationPasswordLastCheck = nil;
        [self hideUI:YES];
    } onError:^(NSError *error) {
        [self hideUI:NO];
    }];
}

- (void)hideUI:(BOOL)success {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD hideHUDForView:_viewController.view animated:YES];
        
        [_viewController dismissViewControllerAnimated:YES completion:^{
            if (success) {
                [self showAlertWithMessage:[BundleUtil localizedStringForKey:@"revocation_request_success"]];
            } else {
                [self showAlertWithMessage:[BundleUtil localizedStringForKey:@"revocation_request_failed"]];
            }
        }];
    });
}

- (void)showAlertWithMessage:(NSString *)message {
    [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:@"" message:message actionOk:nil];
}

- (void)updateLastSetDateForLabel:(UILabel *)label {
    
    label.text = @"...";
    
    ServerAPIConnector *connector = [[ServerAPIConnector alloc] init];
    MyIdentityStore *store = [MyIdentityStore sharedMyIdentityStore];
    
    if (store.revocationPasswordLastCheck == nil) {
        /* Check revocation password now */
        [connector checkRevocationPasswordForStore:store onCompletion:^(BOOL revocationPasswordSet, NSDate *lastChanged) {
            store.revocationPasswordLastCheck = [NSDate date];
            if (revocationPasswordSet)
                store.revocationPasswordSetDate = lastChanged;
            else
                store.revocationPasswordSetDate = nil;
            [self updateLastSetDateForLabelAfterCheck:label];
        } onError:^(NSError *error) {
            label.text = [BundleUtil localizedStringForKey:@"revocation_check_failed"];
        }];
    } else {
        [self updateLastSetDateForLabelAfterCheck:label];
    }
}

- (void)updateLastSetDateForLabelAfterCheck:(UILabel *)label {
    MyIdentityStore *store = [MyIdentityStore sharedMyIdentityStore];
    if (store.revocationPasswordSetDate != nil) {
        label.text = [DateFormatter getShortDate:store.revocationPasswordSetDate];
    } else {
        label.text = [BundleUtil localizedStringForKey:@"revocation_password_not_set"];
    }
}

@end
