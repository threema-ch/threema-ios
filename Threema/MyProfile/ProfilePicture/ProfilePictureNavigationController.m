//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2024 Threema GmbH
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

#import "ProfilePictureNavigationController.h"
#import "PickContactsViewController.h"
#import "NaClCrypto.h"
#import "MyIdentityStore.h"
#import "ModalPresenter.h"
#import "BundleUtil.h"

@interface ProfilePictureNavigationController ()

@end

@implementation ProfilePictureNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.dismissOnTapOutside = NO;
    
    if ([self.topViewController isKindOfClass:[PickContactsViewController class]]) {
        PickContactsViewController *pickContactsController = (PickContactsViewController *)self.topViewController;
        
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:[BundleUtil localizedStringForKey:@"cancel"] style:UIBarButtonItemStyleDone target:self action:@selector(cancelAction:)];
        pickContactsController.navigationItem.leftBarButtonItem = cancelButton;
        
        UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:[BundleUtil localizedStringForKey:@"save"] style:UIBarButtonItemStyleDone target:self action:@selector(saveAction:)];
        pickContactsController.navigationItem.rightBarButtonItem = saveButton;
    }
}

#pragma mark - actions

- (void)cancelAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)saveAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        // save list
    }];
    
}

@end
