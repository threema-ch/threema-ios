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

#import "PrivacySettingsViewController.h"
#import "UserSettings.h"
#import "ContactStore.h"
#import "UIDefines.h"
#import "MDMSetup.h"

@interface PrivacySettingsViewController ()

@end

@implementation PrivacySettingsViewController {
    MDMSetup *mdmSetup;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    self.readReceiptsSwitch.on = [UserSettings sharedUserSettings].sendReadReceipts;
    [[ValidationLogger sharedValidationLogger] logString:[NSString stringWithFormat:@"Read receipts bug: Show flag %@", self.readReceiptsSwitch.on ? @"true" : @"false"]];
    self.syncContactsSwitch.on = [UserSettings sharedUserSettings].syncContacts;
    self.typingIndicatorSwitch.on = [UserSettings sharedUserSettings].sendTypingIndicator;
    self.blockUnknownSwitch.on = [UserSettings sharedUserSettings].blockUnknown;
    self.poiSwitch.on = [UserSettings sharedUserSettings].enablePoi;
        
    [self disabledCellsForMDM];
    
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    if (@available(iOS 11.0, *)) {
        self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    } else {
        self.tableView.estimatedRowHeight = 44.0;
    }
    
    [self.tableView reloadData];
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

- (IBAction)readReceiptsChanged:(id)sender {
    [UserSettings sharedUserSettings].sendReadReceipts = self.readReceiptsSwitch.on;
}

- (IBAction)syncContactsChanged:(id)sender {
    [UserSettings sharedUserSettings].syncContacts = self.syncContactsSwitch.on;
    if (self.syncContactsSwitch.on) {
        [[ContactStore sharedContactStore] synchronizeAddressBookForceFullSync:YES ignoreMinimumInterval:YES onCompletion:nil onError:nil];
    }
}

- (IBAction)typingIndicatorChanged:(id)sender {
    [UserSettings sharedUserSettings].sendTypingIndicator = self.typingIndicatorSwitch.on;
}

- (IBAction)blockUnknownChanged:(id)sender {
    [UserSettings sharedUserSettings].blockUnknown = self.blockUnknownSwitch.on;
    [self.tableView reloadData];
}

- (IBAction)poiChanged:(id)sender {
    [UserSettings sharedUserSettings].enablePoi = self.poiSwitch.on;
}
    
- (void)disabledCellsForMDM {
        BOOL isBlockUnknownManaged = [mdmSetup existsMdmKey:MDM_KEY_BLOCK_UNKNOWN];
        self.blockUnknownCell.userInteractionEnabled = !isBlockUnknownManaged;
        self.blockUnknownLabel.enabled = !isBlockUnknownManaged;
        self.blockUnknownSwitch.enabled = !isBlockUnknownManaged;
        
        BOOL isContactSyncManaged = [mdmSetup existsMdmKey:MDM_KEY_CONTACT_SYNC];
        self.syncContactsCell.userInteractionEnabled = !isContactSyncManaged;
        self.syncContactsLabel.enabled = !isContactSyncManaged;
        self.syncContactsSwitch.enabled = !isContactSyncManaged;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger sections = [super numberOfSectionsInTableView:tableView];
    return sections;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *footer;
    switch (section) {
        case 0:
            
            if ([UserSettings sharedUserSettings].blockUnknown) {
                footer = NSLocalizedString(@"block_unknown_on", nil);
            } else {
                footer = NSLocalizedString(@"block_unknown_off", nil);
            }
            
            if ([mdmSetup existsMdmKey:MDM_KEY_BLOCK_UNKNOWN] || [mdmSetup existsMdmKey:MDM_KEY_CONTACT_SYNC]) {
                footer = [NSString stringWithFormat:@"%@\n\n%@", footer, NSLocalizedString(@"disabled_by_device_policy", nil)];
            }
            return footer;
        default:
            return nil;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
