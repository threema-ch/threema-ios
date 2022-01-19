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

#import <UIKit/UIKit.h>
#import "ThemedTableViewController.h"

@interface PrivacySettingsViewController : ThemedTableViewController

@property (weak, nonatomic) IBOutlet UISwitch *readReceiptsSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *syncContactsSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *typingIndicatorSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *blockUnknownSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *poiSwitch;


@property (weak, nonatomic) IBOutlet UITableViewCell *syncContactsCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *blockUnknownCell;
@property (weak, nonatomic) IBOutlet UILabel *syncContactsLabel;
@property (weak, nonatomic) IBOutlet UILabel *blockUnknownLabel;

- (IBAction)readReceiptsChanged:(id)sender;
- (IBAction)syncContactsChanged:(id)sender;
- (IBAction)typingIndicatorChanged:(id)sender;
- (IBAction)blockUnknownChanged:(id)sender;
- (IBAction)poiChanged:(id)sender;

@end
