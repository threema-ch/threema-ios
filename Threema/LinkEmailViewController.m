//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

#import "LinkEmailViewController.h"
#import "MyIdentityStore.h"
#import "ServerAPIConnector.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "MDMSetup.h"

@interface LinkEmailViewController ()

@end

@implementation LinkEmailViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    _emailTextField.text = [MyIdentityStore sharedMyIdentityStore].linkedEmail;
    
    MDMSetup *mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    if ([mdmSetup readonlyProfile]) {
        _emailTextField.enabled = NO;
    } else {
        [_emailTextField becomeFirstResponder];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [Colors updateKeyboardAppearanceFor:self.emailTextField];
    
    self.tableView.rowHeight = 85.0;
    self.tableView.estimatedRowHeight = 85.0;
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

- (IBAction)cancelAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)saveAction:(id)sender {
    if ([self.emailTextField.text isEqualToString:[MyIdentityStore sharedMyIdentityStore].linkedEmail]) {
        /* no change - nothing to do */
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self.emailTextField resignFirstResponder];
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    ServerAPIConnector *conn = [[ServerAPIConnector alloc] init];
    [conn linkEmailWithStore:[MyIdentityStore sharedMyIdentityStore] email:self.emailTextField.text onCompletion:^(BOOL linked) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
        
        if (self.emailTextField.text.length > 0 && !linked) {
            [UIAlertTemplate showAlertWithOwner:self title:NSLocalizedString(@"link_email_sent_title", nil) message:[NSString stringWithFormat:NSLocalizedString(@"link_email_sent_message", nil), self.emailTextField.text] actionOk:nil];
        }
    } onError:^(NSError *error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        self.navigationItem.rightBarButtonItem.enabled = YES;
        [UIAlertTemplate showAlertWithOwner:self title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
    }];
}


@end
