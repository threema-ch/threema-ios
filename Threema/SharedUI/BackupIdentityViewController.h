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

#import "Threema-Swift.h"

@interface BackupIdentityViewController : ThemedTableViewController <UIActivityItemSource>

@property (nonatomic, strong) NSString *backupData;

@property (weak, nonatomic) IBOutlet CopyLabel *identityBackupLabel;
@property (weak, nonatomic) IBOutlet UIImageView *qrImageView;
@property (weak, nonatomic) IBOutlet UISwitch *phoneBackupSwitch;

- (IBAction)doneAction:(id)sender;
- (IBAction)actionAction:(id)sender;
- (IBAction)phoneBackupSwitchChanged:(id)sender;

@end