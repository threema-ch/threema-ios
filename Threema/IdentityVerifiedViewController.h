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

@class Contact;
@class VerificationLevelCell;

@interface IdentityVerifiedViewController : ThemedTableViewController

@property (strong, nonatomic) Contact* contact;

@property (weak, nonatomic) IBOutlet UIImageView *contactImage;
@property (weak, nonatomic) IBOutlet UIImageView *threemaTypeIcon;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;

@property (weak, nonatomic) IBOutlet UILabel *identityLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *publicKeyCell;
@property (weak, nonatomic) IBOutlet VerificationLevelCell *verificationLevelCell;
@property (weak, nonatomic) IBOutlet UIImageView *verificationLevelImage;

@property (weak, nonatomic) IBOutlet UILabel *sendMessageLabel;
@property (weak, nonatomic) IBOutlet UILabel *threemaCallLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *sendMessageCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *threemaCallCell;

- (IBAction)done:(id)sender;

@end
