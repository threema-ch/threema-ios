//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2023 Threema GmbH
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
#import "BallotMessage.h"
#import "Old_ThemedViewController.h"

@interface BallotVoteViewController : Old_ThemedViewController

@property (weak, nonatomic) IBOutlet UIBarButtonItem *voteButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *cancelButton;

@property (weak, nonatomic) IBOutlet UIView *headerPlaceholderView;

@property (weak, nonatomic) IBOutlet UITableView *choiceTableView;

@property (weak, nonatomic) IBOutlet UIView *adminView;
@property (weak, nonatomic) IBOutlet UIView *summaryView;
@property (weak, nonatomic) IBOutlet UIImageView *detailsImage;

@property (weak, nonatomic) IBOutlet UILabel *countVotesLabel;
@property (weak, nonatomic) IBOutlet UIButton *ballotCloseButton;
@property (weak, nonatomic) IBOutlet UIButton *ballotEditButton;

+ (instancetype) ballotVoteViewControllerForBallot:(Ballot *)ballot;

@end
