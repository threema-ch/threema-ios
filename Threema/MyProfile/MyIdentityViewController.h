//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2023 Threema GmbH
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

@class CopyLabel;

@interface MyIdentityViewController : ThemedTableViewController

@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet UIButton *editButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *nickNameTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *nickNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *threemaIdTitleLabel;
@property (weak, nonatomic) IBOutlet CopyLabel *threemaIdLabel;
@property (weak, nonatomic) IBOutlet UIButton *qrCodeButton;
@property (weak, nonatomic) IBOutlet UIButton *shareIdButton;
@property (weak, nonatomic) IBOutlet UILabel *publicKeyLabel;

@property (weak, nonatomic) IBOutlet UIImageView *qrBackgroundImageView;

@property (weak, nonatomic) IBOutlet UILabel *linkedEmailLabel;
@property (weak, nonatomic) IBOutlet UILabel *linkedMobileNoLabel;
@property (weak, nonatomic) IBOutlet UILabel *threemaSafeLabel;
@property (weak, nonatomic) IBOutlet UILabel *revocationLabelDetail;

@property (weak, nonatomic) IBOutlet UITableViewCell *myIdCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *linkEmailCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *linkPhoneCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *backupCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *threemaSafeCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *idRecoveryCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *deleteIdCell;

- (IBAction)deleteIdentity:(id)sender;

- (void)createBackup;
- (void)startSetPublicNickname;
- (void)scrollToLinkSection;
- (void)showSafeSetup;

@end
