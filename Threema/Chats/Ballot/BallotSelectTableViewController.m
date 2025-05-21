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

#import "BallotSelectTableViewController.h"
#import "EntityCreator.h"
#import "EntityFetcher.h"
#import "BallotListTableCell.h"
#import "BundleUtil.h"

#define BALLOT_LIST_TABLE_CELL_ID @"BallotListTableCellId"
#define MAX_BALLOTS 100

@interface BallotSelectTableViewController ()

@property NSArray *ballots;

@end

@implementation BallotSelectTableViewController

@synthesize entityManager;

- (void)viewDidLoad {
    [super viewDidLoad];

    _cancelButton.target = self;
    _cancelButton.action = @selector(cancelPressed);
    
    [self setTitle:[BundleUtil localizedStringForKey:@"ballot_choose_title"]];
}

- (void)setEntityManager:(EntityManager *)newEntityManager {
    entityManager = newEntityManager;

    [self loadData];
}

- (void)loadData {
    if (!_ballot || !entityManager) {
        return;
    }

    NSFetchRequest *fetchRequest = [entityManager.entityFetcher fetchRequestForEntity:@"Ballot"];
    
    NSArray *sortDescriptors = @[
                                 [NSSortDescriptor sortDescriptorWithKey:@"modifyDate" ascending:NO],
                                 [NSSortDescriptor sortDescriptorWithKey:@"createDate" ascending:NO]
                                 ];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"id != %@", _ballot.id]];
    fetchRequest.fetchLimit = MAX_BALLOTS;
    
    [entityManager performBlockAndWait:^{
        NSArray *result = [entityManager.entityFetcher executeFetchRequest:fetchRequest];
        if (result) {
            _ballots = result;
        } else {
            _ballots = [NSArray array];
        }
    }];

    [[self tableView] reloadData];
}

#pragma mark - button actions

- (void) cancelPressed {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_ballots count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BallotListTableCell *cell = (BallotListTableCell *)[tableView dequeueReusableCellWithIdentifier:BALLOT_LIST_TABLE_CELL_ID forIndexPath:indexPath];
    
    [entityManager performBlockAndWait:^{
        BallotEntity *ballot = [_ballots objectAtIndex: indexPath.row];
        [cell.nameLabel setText:ballot.title];
        [cell.creatorNameLabel setText: [entityManager.entityFetcher displayNameForContactId:ballot.creatorId]];

        NSDate *date;
        if (ballot.modifyDate) {
            date = ballot.modifyDate;
        } else {
            date = ballot.createDate;
        }
        [cell.dateLabel setText: [DateFormatter getShortDate:date]];
    }];

    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [entityManager performBlockAndWait:^{
        BallotEntity *ballot = [_ballots objectAtIndex:indexPath.row];
        
        _ballot.title = ballot.title;
        _ballot.assessmentType = ballot.assessmentType;
        _ballot.choicesType = ballot.choicesType;
        _ballot.type = ballot.type;
            
        [self clearBallotChoices:_ballot];

        for (BallotChoiceEntity *choice in ballot.choices) {
            BallotChoiceEntity *ballotChoice = [[entityManager entityCreator] ballotChoice];
            ballotChoice.name = choice.name;
            ballotChoice.orderPosition = choice.orderPosition;
            ballotChoice.ballot = _ballot;
            [_ballot addChoicesObject: ballotChoice];
        }
    }];
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)clearBallotChoices:(BallotEntity *)ballot {
    for (BallotChoiceEntity *choice in ballot.choices) {
        [ballot.managedObjectContext deleteObject: choice];
    }
    
    [ballot removeChoices:ballot.choices];
}

@end
