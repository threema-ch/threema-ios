//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2021 Threema GmbH
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

@protocol ProgressViewDelegate <NSObject>

- (void)progressViewDidCancel;

@end

@interface ProgressViewController : UIViewController

@property id<ProgressViewDelegate> delegate;

@property (nonatomic) NSInteger totalCount;

@property (weak, nonatomic) IBOutlet UIVisualEffectView *visualEffectsView;
@property (weak, nonatomic) IBOutlet UIView *contentView;

@property (weak, nonatomic) IBOutlet UILabel *label;

@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

- (IBAction)didCancel:(id)sender;

- (void)setProgress:(NSNumber *)progress forItem:(id)item;

- (void)finishedItem:(id)item;

@end
