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

#import "BallotListTableViewController.h"
#import "EntityFetcher.h"
#import "BallotListTableCell.h"
#import "BallotDispatcher.h"
#import "Old_ChatViewController.h"
#import "Old_ChatViewControllerCache.h"
#import "BundleUtil.h"

#define BALLOT_LIST_TABLE_CELL_ID @"BallotListTableCellId"
#define MAX_BALLOTS 50

@interface BallotListTableViewController ()

@property NSArray *openBallots;
@property NSArray *closedBallots;

@property EntityManager *entityManager;

@end

@implementation BallotListTableViewController

+ (instancetype) ballotListViewControllerForConversation:(Conversation *)conversation {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Ballot" bundle:nil];
    
    BallotListTableViewController *viewController = (BallotListTableViewController *) [storyboard instantiateViewControllerWithIdentifier:@"BallotListTableViewController"];
    
    viewController.conversation = conversation;
    
    return viewController;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _entityManager = [[EntityManager alloc] init];
    
    // Only show done button if presented modally
    if (self.presentingViewController) {
        UIBarButtonItem *doneBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
        doneBarButtonItem.accessibilityIdentifier = @"BallotListTableViewControllerDoneBarButtonItem";
        self.navigationItem.rightBarButtonItem = doneBarButtonItem;
    }
}

- (void)done {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [self loadData];
    [self.tableView reloadData];
    
    [self setTitle:[BundleUtil localizedStringForKey:@"ballots"]];
    
    [super viewWillAppear:animated];
}

- (void)loadData {
    NSFetchRequest *fetchRequest = [_entityManager.entityFetcher fetchRequestForEntity:@"Ballot"];
    
    NSArray *sortDescriptors = @[
                                 [NSSortDescriptor sortDescriptorWithKey:@"modifyDate" ascending:NO],
                                 [NSSortDescriptor sortDescriptorWithKey:@"createDate" ascending:NO]
                                 ];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    fetchRequest.fetchLimit = MAX_BALLOTS;

    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"conversation == %@ && state == %d", _conversation, kBallotStateOpen];
    _openBallots = [_entityManager.entityFetcher executeFetchRequest:fetchRequest];

    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"conversation == %@ && state == %d", _conversation, kBallotStateClosed];
    _closedBallots = [_entityManager.entityFetcher executeFetchRequest:fetchRequest];
}

- (Ballot *)ballotForIndexPath:(NSIndexPath *)indexPath {
    Ballot *ballot = nil;
    if (indexPath.section == 0) {
        if (indexPath.row < [_openBallots count]) {
            ballot = [_openBallots objectAtIndex: indexPath.row];
        }
    } else {
        if (indexPath.row < [_closedBallots count]) {
            ballot = [_closedBallots objectAtIndex: indexPath.row];
        }
    }

    return ballot;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [BundleUtil localizedStringForKey:@"ballot_open_ballots"];
    } else {
        return [BundleUtil localizedStringForKey:@"ballot_closed_ballots"];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return [_openBallots count];
    } else {
        return [_closedBallots count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BallotListTableCell *cell = (BallotListTableCell *)[tableView dequeueReusableCellWithIdentifier:BALLOT_LIST_TABLE_CELL_ID];
    
    Ballot *ballot = [self ballotForIndexPath:indexPath];
    
    [cell.nameLabel setText: ballot.title];
    
    NSString *creatorName = [_entityManager.entityFetcher displayNameForContactId:ballot.creatorId];
    [cell.creatorNameLabel setText: creatorName];
    
    NSDate *date;
    if (ballot.modifyDate) {
        date = ballot.modifyDate;
    } else {
        date = ballot.createDate;
    }
    
    [cell.dateLabel setText: [DateFormatter shortStyleDateTime:date]];
    
    cell.accessibilityIdentifier = @"BallotListTableViewControllerBallotListTableCell";
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Ballot *ballot = [self ballotForIndexPath:indexPath];
    if (ballot) {
        [BallotDispatcher showViewControllerForBallot:ballot onNavigationController:self.navigationController];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Table view delegae

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_entityManager performSyncBlockAndSafe:^{
            Ballot *ballot = [self ballotForIndexPath:indexPath];
            for (BaseMessage *message in ballot.message) {
                [[_entityManager entityDestroyer] deleteObjectWithObject:message];
            }
            [[_entityManager entityDestroyer] deleteObjectWithObject:ballot];
            Old_ChatViewController *chatViewController = [Old_ChatViewControllerCache controllerForConversation:_conversation];
            if (chatViewController != nil) {
                [chatViewController updateConversationLastMessage];
                [chatViewController updateConversation];
            }
        }];

        [self loadData];
        
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

@end
