//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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
#import "ChatViewController.h"
#import "HairlineView.h"

@protocol ChatViewSearchHeaderDelegate <NSObject>

- (void)didCancelSearch;

@end

@interface ChatViewSearchHeader : UIView

@property (weak) ChatViewController *chatViewController;
@property id<ChatViewSearchHeaderDelegate> delegate;

@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UIButton *prevButton;
@property (weak, nonatomic) IBOutlet UIButton *nextButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

@property (weak, nonatomic) IBOutlet HairlineView *hairlineView1;
@property (weak, nonatomic) IBOutlet HairlineView *hairlineView2;

- (IBAction)cancelAction:(id)sender;
- (IBAction)prevAction:(id)sender;
- (IBAction)nextAction:(id)sender;

@end
