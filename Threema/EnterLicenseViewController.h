//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2022 Threema GmbH
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
#import "SSLabel.h"
#import "ProgressLabel.h"
#import "ZSWTappableLabel.h"

@protocol EnterLicenseDelegate <NSObject>

- (void)licenseConfirmed;

@end

@interface EnterLicenseViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIStackView *stackView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (weak, nonatomic) IBOutlet UIImageView *feedbackImageView;
@property (weak, nonatomic) IBOutlet UILabel *feedbackLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UITextField *licenseUsernameTextField;
@property (weak, nonatomic) IBOutlet UITextField *licensePasswordTextField;

@property (weak, nonatomic) IBOutlet UIButton *confirmButton;

@property (weak, nonatomic) IBOutlet UIImageView *keyImageView;

@property (weak, nonatomic) IBOutlet ZSWTappableLabel *threemaAppLinkLabel;

@property id<EnterLicenseDelegate> delegate;

- (IBAction)confirmAction:(id)sender;

@end
