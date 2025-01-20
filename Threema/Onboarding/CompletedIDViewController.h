//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2025 Threema GmbH
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
#import "IDCreationPageViewController.h"

@protocol CompletedIDDelegate <NSObject>

-(void)completedIDSetup;

@end

@interface CompletedIDViewController : IDCreationPageViewController

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

@property (weak, nonatomic) IBOutlet UIView *nickNameView;
@property (weak, nonatomic) IBOutlet UILabel *nickNameLabel;

@property (weak, nonatomic) IBOutlet UIView *linkedToView;
@property (weak, nonatomic) IBOutlet UILabel *linkedToLabel;

@property (weak, nonatomic) IBOutlet UIView *syncContactsView;
@property (weak, nonatomic) IBOutlet UILabel *syncContactsLabel;

@property (weak, nonatomic) IBOutlet UIView *enableSafeView;
@property (weak, nonatomic) IBOutlet UILabel *enableSafeLabel;

@property (weak, nonatomic) IBOutlet UILabel *nicknameValue;
@property (weak, nonatomic) IBOutlet UILabel *emailValue;
@property (weak, nonatomic) IBOutlet UILabel *phoneValue;
@property (weak, nonatomic) IBOutlet UILabel *syncContactValue;
@property (weak, nonatomic) IBOutlet UILabel *enableSafeValue;

@property (weak, nonatomic) IBOutlet UIView *emailView;
@property (weak, nonatomic) IBOutlet UIView *phoneView;

@property (weak, nonatomic) IBOutlet UIButton *finishButton;

@property (weak, nonatomic) IBOutlet UIImageView *contactImageView;
@property (weak, nonatomic) IBOutlet UIImageView *phoneImageView;
@property (weak, nonatomic) IBOutlet UIImageView *mailImageView;

- (IBAction)finishAction:(id)sender;

@property (weak) id<CompletedIDDelegate> delegate;

@end
