//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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
#import <ContactsUI/ContactsUI.h>
#import "ThemedTableViewController.h"

@class VerificationLevelCell;

@class KeyFingerprintCell;

@interface NewScannedContactViewController : ThemedTableViewController <CNContactPickerDelegate>

@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (strong, nonatomic) NSString *identity;

@property (strong, nonatomic) NSData *publicKey;
@property (nonatomic) int32_t verificationLevel;
@property (strong, nonatomic) NSString *cnContactId;
@property (strong, nonatomic) NSNumber *state;
@property (strong, nonatomic) NSNumber *type;
@property (strong, nonatomic) NSNumber *featureMask;

@property (weak, nonatomic) IBOutlet UILabel *identityLabel;
@property (weak, nonatomic) IBOutlet UILabel *sendMessageLabel;
@property (weak, nonatomic) IBOutlet UILabel *threemaCallLabel;
@property (weak, nonatomic) IBOutlet KeyFingerprintCell *keyFingerprintCell;

@property (weak, nonatomic) IBOutlet VerificationLevelCell *verificationLevelCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *linkToContactCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *sendMessageCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *threemaCallCell;
@property (weak, nonatomic) IBOutlet UILabel *linkedContactNameLabel;

@property (weak, nonatomic) IBOutlet UIImageView *contactImage;
@property (weak, nonatomic) IBOutlet UIImageView *threemaTypeIcon;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UIButton *editNameButton;

- (IBAction)save:(id)sender;
- (IBAction)cancel:(id)sender;

@end
