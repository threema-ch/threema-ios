//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2024 Threema GmbH
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
#import "ContactEntity.h"
#import "InviteController.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "AppDelegate.h"
#import "GatewayAvatarMaker.h"
#import "UIImage+ColoredImage.h"
#import "NSString+Hex.h"
#import "ServerAPIConnector.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"
#import "MyIdentityStore.h"
#import "BundleUtil.h"

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
    
    self.identityTextField.accessibilityIdentifier = @"AddContactViewControllerCTextField";
    
    // Tint icon appropriately
    self.scanIdentityCell.imageView.image = [self.scanIdentityCell.imageView.image imageWithTint:UIColor.primary];
    
    [Colors updateKeyboardAppearanceFor:self.identityTextField];
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(applicationDidEnterBackground:) name: UIApplicationDidEnterBackgroundNotification object: nil];
    
    [self configureNavigationBar];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.identityTextField becomeFirstResponder];
}

- (void)configureNavigationBar {
    // A bar button item needs to be assigned the title before it is added to the
    // navigation bar
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:[BundleUtil localizedStringForKey:@"add_button"] style:UIBarButtonItemStyleDone target:self action:@selector(doAdd)];
    item.accessibilityIdentifier = @"AddContactModalAddButton";
    self.navigationItem.rightBarButtonItem = item;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    self.navigationController.navigationBar.accessibilityIdentifier = @"AddContactModalNavigationBar";
}

- (void)refresh {
    [self updateColors];
    
    [super refresh];
}

- (void)updateColors {
    [super updateColors];
    
    [self.navigationController.view setBackgroundColor:Colors.backgroundNavigationController];
}


# pragma mark - Actions

- (IBAction)cancelAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
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


#pragma mark - Table view delegate

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

#pragma mark - Text field delegate

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
    NSString *enteredId = self.identityTextField.text;
    
    NSString *myIdentity = MyIdentityStore.sharedMyIdentityStore.identity;
    if (enteredId.length != kIdentityLen || [enteredId isEqualToString:myIdentity]) {
        return NO;
    }
    
    if (self.view != nil) {
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    }
    
    [[ContactStore sharedContactStore] addContactWithIdentity:enteredId verificationLevel:kVerificationLevelUnverified onCompletion:^(ContactEntity * _Nullable contact, __unused BOOL alreadyExists) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        
        [self dismissViewControllerAnimated:YES completion:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowContact object:nil userInfo:[NSDictionary dictionaryWithObject:contact forKey:kKeyContact]];
        }];
    } onError:^(NSError * _Nonnull error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        
        if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == 404) {
            [UIAlertTemplate showAlertWithOwner:self title:[BundleUtil localizedStringForKey:@"identity_not_found_title"] message:[BundleUtil localizedStringForKey:@"identity_not_found_message"] actionOk:nil];
            
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
