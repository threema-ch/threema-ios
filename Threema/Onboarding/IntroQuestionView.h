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

@class IntroQuestionView;

@protocol IntroQuestionDelegate <NSObject>

@optional
- (void)selectedYes:(IntroQuestionView *)sender;

@optional
- (void)selectedNo:(IntroQuestionView *)sender;

@optional
- (void)selectedOk:(IntroQuestionView *)sender;

@end

@interface IntroQuestionView : UIView

@property BOOL showOnlyOkButton;

@property (nonatomic) NSString *title;

@property (weak, nonatomic) IBOutlet UILabel *questionTitle;
@property (weak, nonatomic) IBOutlet UILabel *questionLabel;
@property (weak, nonatomic) IBOutlet UIStackView *alertPane;
@property (weak, nonatomic) IBOutlet UIStackView *confirmPane;
@property (weak, nonatomic) IBOutlet UIButton *noButton;
@property (weak, nonatomic) IBOutlet UIButton *yesButton;
@property (weak, nonatomic) IBOutlet UIButton *okButton;

@property id<IntroQuestionDelegate> delegate;

- (IBAction)yesAction:(id)sender;
- (IBAction)noAction:(id)sender;
- (IBAction)okAction:(id)sender;

@end
