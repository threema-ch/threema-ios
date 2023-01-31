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
#import "ScanBackupController.h"
#import "IDCreationPageViewController.h"

@protocol RestoreIdentityViewControllerDelegate <NSObject>

-(void)restoreIdentityDone;
-(void)restoreIdentityCancelled;

@end

@interface RestoreIdentityViewController : IDCreationPageViewController <UITextViewDelegate, UITextFieldDelegate, ScanBackupControllerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@property (weak, nonatomic) IBOutlet UIView *textViewBackground;
@property (weak, nonatomic) IBOutlet UITextView *backupTextView;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property (weak, nonatomic) IBOutlet UIView *passwordFieldBackground;
@property (weak, nonatomic) IBOutlet SSLabel *backupLabel;

@property (weak) id<RestoreIdentityViewControllerDelegate> delegate;

@property (weak, nonatomic) IBOutlet UIView *scanView;
@property (weak, nonatomic) IBOutlet UILabel *scanLabel;
@property (weak, nonatomic) IBOutlet UIView *passwordView;
@property (weak, nonatomic) IBOutlet UIView *buttonsView;
@property (weak, nonatomic) IBOutlet UIImageView *scanImageView;

@property (weak, nonatomic) IBOutlet UIButton *doneButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

@property (weak, nonatomic) IBOutlet UIImageView *keyImageView;

@property NSString *backupData;
@property NSString *passwordData;

- (IBAction)doneAction:(id)sender;
- (IBAction)cancelAction:(id)sender;

- (void)setup;

- (void)handleError:(NSError *)error;
- (void)updateTextViewWithBackupCode;

@end
