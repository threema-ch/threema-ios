//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2024 Threema GmbH
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

#import <UIKit/UIKit.h>
#import "ThemedTableViewController.h"

@interface AdvancedSettingsViewController : ThemedTableViewController

@property (weak, nonatomic) IBOutlet UISwitch *enableIPv6Switch;
@property (weak, nonatomic) IBOutlet UISwitch *validationLoggingSwitch;
@property (weak, nonatomic) IBOutlet UILabel *logSizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *sentryAppDeviceLabel;
@property (weak, nonatomic) IBOutlet UISwitch *proximityMonitoringSwitch;
@property (weak, nonatomic) IBOutlet UITableViewCell *flushMessageQueueCell;
@property (weak, nonatomic) IBOutlet UILabel *orphanedFilesCleanupLabel;
@property (weak, nonatomic) IBOutlet UILabel *contactsCleanupLabel;
@property (weak, nonatomic) IBOutlet UILabel *reregisterPushNotificationsLabel;
@property (weak, nonatomic) IBOutlet UILabel *resetFSDBLabel;
@property (weak, nonatomic) IBOutlet UILabel *resetUnreadCountLabel;


- (IBAction)enableIPv6Changed:(id)sender;
- (IBAction)validationLoggingChanged:(id)sender;
- (IBAction)proximityMonitoringChanged:(id)sender;

@end
