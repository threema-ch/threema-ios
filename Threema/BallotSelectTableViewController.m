//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2022 Threema GmbH
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
#import "EntityManager.h"
#import "BallotListTableCell.h"

#define BALLOT_LIST_TABLE_CELL_ID @"BallotListTableCellId"
#define MAX_BALLOTS 100

@interface BallotSelectTableViewController ()

@property NSArray *ballots;
@property EntityManager *entityManager;

@end

@implementation BallotSelectTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _entityManager = [[EntityManager alloc] init];

    [self loadData];
    
    _cancelButton.target = self;
    _cancelButton.action = @selector(cancelPressed);
    
    [self setTitle:NSLocalizedStringFromTable(@"ballot_choose_title", @"Ballot", nil)];
}

- (void)loadData {
    NSFetchRequest *fetchRequest = [_entityManager.entityFetcher fetchRequestForEntity:@"Ballot"];
    
    NSArray *sortDescriptors = @[
                                 [NSSortDescriptor sortDescriptorWithKey:@"modifyDate" ascending:NO],
                                 [NSSortDescriptor sortDescriptorWithKey:@"createDate" ascending:NO]
                                 ];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    fetchRequest.fetchLimit = MAX_BALLOTS;
    
    NSArray *result = [_entityManager.entityFetcher executeFetchRequest:fetchRequest];
    if (result) {
        _ballots = result;
    } else {
        _ballots = [NSArray array];
    }
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
    
    Ballot *ballot = [_ballots objectAtIndex: indexPath.row];
    [cell.nameLabel setText: ballot.title];
    
    NSString *creatorName = [_entityManager.entityFetcher displayNameForContactId:ballot.creatorId];
    [cell.creatorNameLabel setText: creatorName];
    
    NSDate *date;
    if (ballot.modifyDate) {
        date = ballot.modifyDate;
    } else {
        date = ballot.createDate;
    }
    
    [cell.dateLabel setText: [DateFormatter getShortDate:date]];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    EntityCreator *entityCreator = [[EntityCreator alloc] initWith:_ballot.managedObjectContext];
    
    Ballot *ballot = [_ballots objectAtIndex: indexPath.row];
    
    _ballot.title = [ballot.title copy];
    _ballot.assessmentType = [ballot.assessmentType copy];
    _ballot.choicesType = [ballot.choicesType copy];
    _ballot.type = [ballot.type copy];
    
    [self clearBallotChoices];
    
    for (BallotChoice *choice in ballot.choices) {
        BallotChoice *ballotChoice = [entityCreator ballotChoice];
        ballotChoice.name = [choice.name copy];
        ballotChoice.orderPosition = [choice.orderPosition copy];
        ballotChoice.ballot = _ballot;
        
        [_ballot addChoicesObject: ballotChoice];
    }

    [self.navigationController popViewControllerAnimated:YES];
}

- (void)clearBallotChoices {
    for (BallotChoice *choice in _ballot.choices) {
        [_ballot.managedObjectContext deleteObject: choice];
    }
    
    [_ballot removeChoices:_ballot.choices];

}

@end
