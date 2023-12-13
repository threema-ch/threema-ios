//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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

#import "BackupPasswordViewController.h"
#import "BackupPasswordVerifyViewController.h"
#import "UIDefines.h"
#import "BundleUtil.h"

@interface BackupPasswordViewController ()

@end

@implementation BackupPasswordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [Colors updateKeyboardAppearanceFor:self.passwordField];
    
    self.tableView.rowHeight = 85.0;
    self.tableView.estimatedRowHeight = 85.0;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActiveNotification:) name:UIApplicationWillResignActiveNotification object:nil];
    
    
    if (self.passwordField.text.length < kMinimumPasswordLength) {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    } else {
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
    
    self.passwordField.delegate = self;
    
    [self.passwordField becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.passwordField.delegate = nil;
    
    [self.passwordField resignFirstResponder];
    
    [[NSNotificationCenter defaultCenter] removeObserver:UIApplicationDidEnterBackgroundNotification];
}

- (void)setPasswordTitle:(NSString *)passwordTitle {
    if (passwordTitle && [passwordTitle length] > 0) {
        _titleNavigationItem.title = passwordTitle;
    }
}

-(NSString *)passwordTitle {
    return _titleNavigationItem.title;
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

- (IBAction)nextAction:(id)sender {
    if (self.passwordField.text.length < kMinimumPasswordLength) {
        [UIAlertTemplate showAlertWithOwner:self title:[BundleUtil localizedStringForKey:@"password_too_short_title"] message:[BundleUtil localizedStringForKey:@"password_too_short_message"] actionOk:nil];
        return;
    } else {
        [self performSegueWithIdentifier:@"VerifyPassword" sender:self];
    }
}

- (IBAction)cancelAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"VerifyPassword"]) {
        BackupPasswordVerifyViewController *verifyVc = (BackupPasswordVerifyViewController*)segue.destinationViewController;
        verifyVc.chosenPassword = self.passwordField.text;
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

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self nextAction:textField];
    
    return NO;
}

- (void)refresh {
    [self updateColors];
    
    for (UITableViewCell *cell in self.tableView.visibleCells) {
        [Colors updateWithCell:cell setBackgroundColor:true];
    }
}


#pragma mark - UITableViewDataSource

-(NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return _passwordAdditionalText;
}

#pragma mark - Notifications

- (void)applicationWillResignActiveNotification:(NSNotification*)note {
    [self dismissViewControllerAnimated:NO completion:nil];
}

@end
