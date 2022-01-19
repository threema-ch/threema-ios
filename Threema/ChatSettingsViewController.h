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

@interface ChatSettingsViewController : ThemedTableViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *wallpaperImageView;

@property (weak, nonatomic) IBOutlet UILabel *fontSizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *biggerEmojiLabel;
@property (weak, nonatomic) IBOutlet UISwitch *showReceivedTimestampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *returnToSendSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *biggerEmojiSwitch;

- (IBAction)showReceivedTimestampChanged:(id)sender;
- (IBAction)returnToSendChanged:(id)sender;
- (IBAction)biggerEmojiChanged:(id)sender;

@end
