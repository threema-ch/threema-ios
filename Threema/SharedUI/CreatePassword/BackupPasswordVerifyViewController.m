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

#import "BackupPasswordVerifyViewController.h"
#import "BackupIdentityViewController.h"
#import "UIDefines.h"
#import "MyIdentityStore.h"
#import "Threema-Swift.h"

@interface BackupPasswordVerifyViewController ()
@property (weak, nonatomic) IBOutlet UILabel *enterAgainLabel;
@end

@implementation BackupPasswordVerifyViewController {
    NSString *backupData;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [Colors updateKeyboardAppearanceFor:self.passwordField];
    
    self.tableView.rowHeight = 85.0;
    self.tableView.estimatedRowHeight = 85.0;
    
    self.title = [BundleUtil localizedStringForKey:@"password_again"];
    self.navigationItem.rightBarButtonItem.title = [BundleUtil localizedStringForKey:@"next"];
    self.enterAgainLabel.text = [BundleUtil localizedStringForKey:@"backup_password_verify_enter_again_label"];
    self.passwordField.placeholder = [BundleUtil localizedStringForKey:@"Password"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (self.passwordField.text.length < kMinimumPasswordLength) {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    } else {
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
    
    self.passwordField.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.passwordField becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.passwordField.delegate = nil;
    
    [self.passwordField resignFirstResponder];
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

- (void)refresh {
    [self updateColors];
}

- (IBAction)nextAction:(id)sender {
    if (![self.passwordField.text isEqualToString:self.chosenPassword]) {
        [UIAlertTemplate showAlertWithOwner:self title:[BundleUtil localizedStringForKey:@"password_mismatch_title"] message:[BundleUtil localizedStringForKey:@"password_mismatch_message"] actionOk:nil];
        return;
    }
    
    if (_passwordCallback) {
        self.navigationItem.rightBarButtonItem.enabled = NO;
        [_passwordCallback passwordResult: self.chosenPassword fromViewController: self];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ShowBackup"]) {
        BackupIdentityViewController *idVc = (BackupIdentityViewController*)segue.destinationViewController;
        idVc.backupData = backupData;
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (newText.length < kMinimumPasswordLength) {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    } else {
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
    
    return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    if (textField.text.length < kMinimumPasswordLength) {
        return NO;
    }
    return YES;
}

-(NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return [BundleUtil localizedStringForKey:@"backup_password_verify_footer"];
}

@end
