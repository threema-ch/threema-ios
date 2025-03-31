//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2025 Threema GmbH
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

#import "SyncContactsViewController.h"
#import "UserSettings.h"
#import "LicenseStore.h"
#import "MDMSetup.h"

@interface SyncContactsViewController ()

@end

@implementation SyncContactsViewController {
    MDMSetup *mdmSetup;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        mdmSetup = [[MDMSetup alloc] initWithSetup:YES];
   }
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.syncContactsSwitch.on = YES;

    [self setup];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if ([mdmSetup existsMdmKey:MDM_KEY_CONTACT_SYNC]) {
        self.syncContactsSwitch.on = [UserSettings sharedUserSettings].syncContacts;
        self.syncContactsSwitch.enabled = false;
    } else {
        [UserSettings sharedUserSettings].syncContacts = self.syncContactsSwitch.on;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.titleLabel);
}

- (IBAction)syncContactSwitchChanged:(id)sender {
    [UserSettings sharedUserSettings].syncContacts = _syncContactsSwitch.on;
}

- (void)setup {
    if (TargetManagerObjc.isBusinessApp) {
        _titleLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"id_sync_title_work"], TargetManagerObjc.appName];
        _descriptionLabel.text = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"id_sync_description_work"], TargetManagerObjc.appName];
    } else {
        _titleLabel.text = [BundleUtil localizedStringForKey:@"id_sync_title"];
        _descriptionLabel.text = [BundleUtil localizedStringForKey:@"id_sync_description"];
    }
    _syncContactsLabel.text = [BundleUtil localizedStringForKey:@"id_sync_contacts"];

    self.moreView.mainView = self.mainContentView;
    self.moreView.moreMessageText = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"more_information_sync_contacts"], TargetManagerObjc.appName];
    
    _syncContactsView.layer.cornerRadius = 3;
    _syncContactsView.layer.borderColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.1].CGColor;
    _syncContactsView.layer.borderWidth = 0.5;
    self.syncContactsSwitch.enabled = ![mdmSetup existsMdmKey:MDM_KEY_CONTACT_SYNC];
    
    _syncContactsSwitch.onTintColor = UIColor.primary;
}

- (BOOL)isInputValid {
    if ([self.moreView isShown]) {
        return NO;
    }
    
    return YES;
}

@end
