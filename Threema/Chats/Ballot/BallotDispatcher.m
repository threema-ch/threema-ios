//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2025 Threema GmbH
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

#import "BallotDispatcher.h"
#import "BallotVoteViewController.h"
#import "BallotCreateViewController.h"
#import "BallotResultViewController.h"
#import "ModalNavigationController.h"

@implementation BallotDispatcher

+ (UIViewController *)viewControllerForBallot:(Ballot *)ballot {
    if ([ballot isClosed]) {
        return [BallotResultViewController ballotResultViewControllerForBallot: ballot];
    } else {
        return [BallotVoteViewController ballotVoteViewControllerForBallot: ballot];
    }
}

+ (void)showViewControllerForBallot:(Ballot *)ballot onNavigationController:(UINavigationController*)navigationController {
    /* present open ballots as modal dialogs as the user must take action or cancel, and simply push closed ballots */
    if ([ballot isClosed]) {
        BallotResultViewController *viewController = [BallotResultViewController ballotResultViewControllerForBallot: ballot];
        [self presentAsModal:viewController onNavigationController:navigationController];
    } else {
        BallotVoteViewController *viewController = [BallotVoteViewController ballotVoteViewControllerForBallot: ballot];
        [self presentAsModal:viewController onNavigationController:navigationController];
    }
}

+ (void)showBallotCreateViewControllerForConversation:(ConversationEntity *)conversation onNavigationController:(UINavigationController*)navigationController {
    BallotCreateViewController *viewController = [BallotCreateViewController ballotCreateViewControllerForConversation: conversation];
    ModalNavigationController *modalNav = [[ModalNavigationController alloc] initWithRootViewController:viewController];
    modalNav.modalInPresentation = YES;
    [navigationController presentViewController:modalNav animated:YES completion:nil];
}

+ (void)presentAsModal:(UIViewController*)viewController onNavigationController:(UINavigationController*)navigationController {
    ModalNavigationController *modalNav = [[ModalNavigationController alloc] initWithRootViewController:viewController];
    [navigationController presentViewController:modalNav animated:YES completion:nil];
}

@end
