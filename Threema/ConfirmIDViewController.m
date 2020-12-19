//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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

#import "ConfirmIDViewController.h"
#import "MyIdentityStore.h"
#import "LicenseStore.h"

@interface ConfirmIDViewController ()

@end

@implementation ConfirmIDViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setup];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.idLabel.text = [MyIdentityStore sharedMyIdentityStore].identity;
}

- (void)setup {
    if ([LicenseStore requiresLicenseKey]) {
        _descriptionLabel.text = [BundleUtil localizedStringForKey:@"id_confirm_description_work"];
        _titleLabel.text = [BundleUtil localizedStringForKey:@"welcome_work"];
    } else {
        _descriptionLabel.text = [BundleUtil localizedStringForKey:@"id_confirm_description"];
        _titleLabel.text = [BundleUtil localizedStringForKey:@"welcome"];
    }
    _yourIdLabel.text = [BundleUtil localizedStringForKey:@"id_confirm_your_id"];

    self.moreView.mainView = self.mainContentView;
    self.moreView.moreMessageText = [BundleUtil localizedStringForKey:@"more_information_confirm_id"];
    
    _idLabel.textColor = [Colors mainThemeDark];
}

- (BOOL)isInputValid {
    if ([self.moreView isShown]) {
        return NO;
    }
    
    return YES;
}

@end
