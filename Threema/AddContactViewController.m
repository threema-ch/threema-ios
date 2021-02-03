//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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

#import "AddContactViewController.h"
#import "ScanIdentityController.h"
#import "ProtocolDefines.h"
#import "ContactStore.h"
#import "Contact.h"
#import "InviteController.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "NewScannedContactViewController.h"
#import "AppDelegate.h"
#import "GatewayAvatarMaker.h"
#import "UIImage+ColoredImage.h"
#import "NSString+Hex.h"
#import "ServerAPIConnector.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"
#import "MyIdentityStore.h"

@interface AddContactViewController ()

@end

@implementation AddContactViewController {
    InviteController *inviteController;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (![ScanIdentityController canScan]) {
        self.scanIdentityCell.selectionStyle = UITableViewCellSelectionStyleNone;
        self.scanIdentityCell.imageView.alpha = 0.4;
        self.scanIdentityCell.textLabel.alpha = 0.4;
    }
    
    // Tint icon appropriately
    self.scanIdentityCell.imageView.image = [self.scanIdentityCell.imageView.image imageWithTint:[Colors main]];
    
    [Colors updateKeyboardAppearanceFor:self.identityTextField];
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(applicationDidEnterBackground:) name: UIApplicationDidEnterBackgroundNotification object: nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.identityTextField becomeFirstResponder];
}

- (IBAction)cancelAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)doneAction:(id)sender {
    [self doAdd];
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}


#pragma mark - Text field delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 1 && indexPath.row == 0) {
        /* Scan */
        if ([ScanIdentityController canScan]) {
            ScanIdentityController *scanController = [[ScanIdentityController alloc] init];
            scanController.containingViewController = self.presentingViewController;
            
            [self dismissViewControllerAnimated:YES completion:^{
                [scanController startScan];
                
                /* a good opportunity to sync contacts - maybe we find the contact
                   that the user is about to scan */
                [[ContactStore sharedContactStore] synchronizeAddressBookForceFullSync:YES onCompletion:nil onError:nil];
            }];
        }
    } else if (indexPath.section == 1 && indexPath.row == 1) {
        [_identityTextField resignFirstResponder];
        
        /* Invite a friend */
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        inviteController = [[InviteController alloc] init];
        inviteController.parentViewController = self.presentingViewController;
        inviteController.shareViewController = self;
        inviteController.actionSheetViewController = self;
        inviteController.rect = [tableView rectForRowAtIndexPath:indexPath];
        inviteController.delegate = self;
        inviteController.rect = [tableView rectForRowAtIndexPath:indexPath];
        [inviteController invite];
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    // Check if the added string contains lowercase characters.
    // If so, those characters are replaced by uppercase characters.
    // But this has the effect of losing the editing point
    // (only when trying to edit with lowercase characters),
    // because the text of the UITextField is modified.
    // That is why we only replace the text when this is really needed.
    NSRange lowercaseCharRange;
    lowercaseCharRange = [string rangeOfCharacterFromSet:[NSCharacterSet lowercaseLetterCharacterSet]];
    
    if (lowercaseCharRange.location != NSNotFound) {
        
        // Get current cursor position
        UITextRange *selectedTextRangeCurrent = textField.selectedTextRange;
        
        textField.text = [textField.text stringByReplacingCharactersInRange:range
                                                                 withString:[string uppercaseString]];
        if (selectedTextRangeCurrent != nil) {
            // Set current cursor position, if cursor position + 1 is valid
            UITextPosition *newPosition = [textField positionFromPosition:selectedTextRangeCurrent.start offset:1];
            if (newPosition != nil) {
                textField.selectedTextRange = [textField textRangeFromPosition:newPosition toPosition:newPosition];
            }
        }

        self.navigationItem.rightBarButtonItem.enabled = (textField.text.length == kIdentityLen);
        return NO;
    }
    
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    self.navigationItem.rightBarButtonItem.enabled = (newText.length == kIdentityLen);
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    return [self doAdd];
}

- (BOOL)doAdd {
    NSString *myIdentity = MyIdentityStore.sharedMyIdentityStore.identity;
    if (self.identityTextField.text.length != kIdentityLen || [self.identityTextField.text isEqualToString:myIdentity])
        return NO;
    
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
    [conn fetchIdentityInfo:self.identityTextField.text onCompletion:^(NSData *publicKey, NSNumber *state, NSNumber *type, NSNumber *featureMask) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        
        UIViewController *presentingViewController = self.presentingViewController;
        [self dismissViewControllerAnimated:YES completion:^{
            UIStoryboard *storyboard = [AppDelegate getMainStoryboard];
            UINavigationController *newNavVc = [storyboard instantiateViewControllerWithIdentifier:@"NewScannedContact"];
            NewScannedContactViewController *newVc = [newNavVc.viewControllers objectAtIndex:0];
            newVc.identity = self.identityTextField.text;
            newVc.publicKey = publicKey;
            newVc.verificationLevel = kVerificationLevelUnverified;
            newVc.state = state;
            newVc.type = type;
            newVc.featureMask = featureMask;
            
            [presentingViewController presentViewController:newNavVc animated:YES completion:nil];
        }];
    } onError:^(NSError *error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        
        if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == 404) {
            [UIAlertTemplate showAlertWithOwner:self title:NSLocalizedString(@"identity_not_found_title", nil) message:NSLocalizedString(@"identity_not_found_message", nil) actionOk:nil];
            
        } else {
            [UIAlertTemplate showAlertWithOwner:self title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
        }
    }];
    
    return YES;
}

#pragma mark - Invite controller delegate

- (BOOL)inviteControllerShouldDeferMailComposer:(InviteController *)_inviteController {
    [self dismissViewControllerAnimated:YES completion:^{
        [inviteController presentMailComposer];
    }];
    return YES;
}

- (BOOL)inviteControllerShouldDeferMessageComposer:(InviteController *)_inviteController {
    [self dismissViewControllerAnimated:YES completion:^{
        [inviteController presentMessageComposer];
    }];
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [_identityTextField resignFirstResponder];
}

@end
