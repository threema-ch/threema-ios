//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2021 Threema GmbH
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

#import "BallotVoteViewController.h"
#import "Contact.h"
#import "BallotVoteTableCell.h"
#import "BallotChoice.h"
#import "BallotResult.h"
#import "MyIdentityStore.h"
#import "EntityManager.h"
#import "Ballot.h"
#import "MessageSender.h"
#import "BallotManager.h"
#import "RectUtil.h"
#import "BallotHeaderView.h"
#import "BallotCreateViewController.h"
#import "BallotResultViewController.h"
#import "UIImage+ColoredImage.h"
#import "PermissionChecker.h"
#import "NibUtil.h"

#define BALLOT_VOTE_TABLE_CELL_ID @"BallotVoteTableCellId"
#define BALLOT_CLOSE_ACK_MESSAGE NSLocalizedStringFromTable(@"ballot_close_ack", @"Ballot", nil)

@interface BallotVoteViewController () <UITableViewDelegate, UITableViewDataSource>

@property NSArray *choices;
@property EntityManager *entityManager;
@property BallotManager *ballotManager;
@property Ballot *ballot;

@property BallotHeaderView *headerView;

@end

@implementation BallotVoteViewController

+ (instancetype) ballotVoteViewControllerForBallot:(Ballot *)ballot {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Ballot" bundle:nil];
    
    BallotVoteViewController *viewController = (BallotVoteViewController *) [storyboard instantiateViewControllerWithIdentifier:@"BallotVoteViewController"];
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    viewController.entityManager = entityManager;
    viewController.ballotManager = [BallotManager ballotManagerWithEntityManager: entityManager];
    viewController.ballot = (Ballot *)[entityManager.entityFetcher getManagedObjectById:ballot.objectID];
    
    return viewController;
}

-(void)viewWillLayoutSubviews {
    if (_adminView.hidden && !_summaryView.hidden) {
        _summaryView.frame = [RectUtil setYPositionOf:_summaryView.frame y:CGRectGetMaxY(self.view.frame) - CGRectGetHeight(_summaryView.frame)];
    }
    
    CGFloat top = self.topLayoutGuide.length;
    _headerPlaceholderView.frame = [RectUtil setYPositionOf:_headerPlaceholderView.frame y:top];
    _choiceTableView.frame = [RectUtil setYPositionOf:_choiceTableView.frame y:CGRectGetMaxY(_headerPlaceholderView.frame)];
    
    CGFloat height;
    if (_summaryView.hidden) {
        height = self.view.bounds.size.height - CGRectGetMaxY(_headerPlaceholderView.frame);
    } else {
        height = CGRectGetMinY(_summaryView.frame) - CGRectGetMaxY(_headerPlaceholderView.frame);
    }
    _choiceTableView.frame = [RectUtil setHeightOf:_choiceTableView.frame height:height];
}

- (void)viewWillAppear:(BOOL)animated {
    [self updateContent];
    
    if (animated) {
        [_headerView bounceDetailView];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _choiceTableView.delegate = self;
    _choiceTableView.dataSource = self;
    
    _cancelButton.target = self;
    _cancelButton.action = @selector(cancelPressed);
    
    _voteButton.target = self;
    _voteButton.action = @selector(votePressed);
    
    _adminView.hidden = ![_ballot canEdit];
    _summaryView.hidden = ![_ballot isIntermediate] && ![_ballot canEdit];
    
    if ([_ballot isIntermediate]) {
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(resultsTapped)];
        [_summaryView addGestureRecognizer:tapGesture];
        _summaryView.accessibilityTraits = UIAccessibilityTraitButton;
        _summaryView.isAccessibilityElement = YES;
        
        _detailsImage.hidden = NO;
        
        UIImage *tmpImage = [UIImage imageNamed:@"ArrowNext"];
        _detailsImage.image = [tmpImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _detailsImage.tintColor = [UIColor whiteColor];
    } else {
        _detailsImage.hidden = YES;
    }
    
    [_ballotCloseButton addTarget:self action:@selector(ballotClosePressed) forControlEvents:UIControlEventTouchUpInside];
    [_ballotEditButton addTarget:self action:@selector(ballotEditPressed) forControlEvents:UIControlEventTouchUpInside];
    
    _headerView = (BallotHeaderView *)[NibUtil loadViewFromNibWithName:@"BallotHeaderView"];
    _headerView.ballot = _ballot;
    _headerView.frame = _headerPlaceholderView.bounds;
    [_headerPlaceholderView addSubview: _headerView];
    
    _voteButton.title = NSLocalizedStringFromTable(@"ballot_vote", @"Ballot", nil);
    [_ballotCloseButton setTitle:NSLocalizedStringFromTable(@"ballot_close", @"Ballot", nil) forState:UIControlStateNormal];
    
    [self setupColors];
}

- (void)setupColors {
    self.view.backgroundColor = [Colors background];
    _adminView.backgroundColor = [Colors backgroundDark];
    
    _summaryView.backgroundColor = [Colors backgroundInverted];
    _countVotesLabel.textColor = [Colors white];
    
    _choiceTableView.backgroundColor = [Colors background];
    
    [_ballotCloseButton setBackgroundColor:[Colors background]];
    [_ballotCloseButton setTitleColor:[Colors main] forState:UIControlStateNormal];
    
    _headerView.backgroundColor = [Colors background];
}

- (void)updateContent {
    _choices = [_ballot choicesSortedByOrder];
    
    [self setTitle:NSLocalizedStringFromTable(@"ballot", @"Ballot", nil)];
    
    if (_ballot.conversation == nil) {
        _voteButton.enabled = NO;
    }
    
    if (![[PermissionChecker permissionChecker] canSendIn:_ballot.conversation entityManager: nil]) {
        _voteButton.enabled = NO;
    }
    
    NSString *messageFormat = NSLocalizedStringFromTable(@"ballot_got_votes_count", @"Ballot", nil);
    NSInteger countParticipants = _ballot.participantCount;
    NSInteger countVotes = _ballot.numberOfReceivedVotes;
    
    NSString *message = [NSString stringWithFormat:messageFormat, countVotes, countParticipants];
    
    _countVotesLabel.text = message;
    _summaryView.accessibilityValue = message;
}

- (NSString *)choiceTextAt:(NSInteger)index {
    BallotChoice *choice = [_choices objectAtIndex: index];
    
    return choice.name;
}

- (NSString *)voteCountTextAt:(NSInteger)index {
    BallotChoice *choice = [_choices objectAtIndex: index];
    NSInteger count = [choice totalCountOfResultsTrue];
    
    return [NSString stringWithFormat:@"%li", (long)count];
}

- (void)setResult:(BOOL)value forChoiceAt:(NSInteger)index {
    if ([_ballot isMultipleChoice] == NO) {
        [self resetAllValues];
    }
    
    BallotChoice *choice = [_choices objectAtIndex:index];
    
    [_ballotManager updateChoice:choice withOwnResult: [NSNumber numberWithBool:value]];
    
    [self updateTable];
}

- (BOOL)resultForChoiceAt:(NSInteger)index {
    BallotChoice *choice = [_choices objectAtIndex:index];
    
    BallotResult *result = [choice getOwnResult];
    if (result) {
        return [result boolValue];
    }
    
    return NO;
}

- (void)resetAllValues {
    for (BallotChoice *choice in _choices) {
        [_ballotManager updateChoice:choice withOwnResult: [NSNumber numberWithBool: NO]];
    }
}

- (void)updateTable {
    for (NSInteger i=0; i<[_choices count]; i++) {
        NSIndexPath *index = [NSIndexPath indexPathForRow:i inSection:0];
        BallotVoteTableCell *cell = (BallotVoteTableCell *)[_choiceTableView cellForRowAtIndexPath: index];
        
        [self updateCheckmarkForCell:cell atIndexPath: index];
        [self updateAccessabilityLabelForCell:cell];
    }
}

- (void)updateCheckmarkForCell:(BallotVoteTableCell *)cell atIndexPath:(NSIndexPath *) indexPath {
    BOOL selected = [self resultForChoiceAt:indexPath.row];
    
    cell.checkmarkView.hidden = !selected;
}

- (void)checkBallotClosed {
    if ([_ballot isClosed]) {
        _voteButton.enabled = NO;
        _choiceTableView.userInteractionEnabled = NO;
        
        NSString *title = NSLocalizedStringFromTable(@"ballot_vote_ballot_closed_title", @"Ballot", nil);
        NSString *message = NSLocalizedStringFromTable(@"ballot_vote_ballot_closed_message", @"Ballot", nil);
        [UIAlertTemplate showAlertWithOwner:self title:title message:message actionOk:nil];
    }
}

- (void)setDefaultResultsIfMissing {
    for (BallotChoice *choice in [_ballot choices]) {
        if ([choice getOwnResult] == nil) {
            // add default value
            [_ballotManager updateChoice:choice withOwnResult:[NSNumber numberWithBool:NO]];
        }
    }
}

- (void)showBallotCloseAcknowledgeAlert {
    NSString *title = NSLocalizedStringFromTable(@"ballot_close", @"Ballot", nil);
    NSString *message = BALLOT_CLOSE_ACK_MESSAGE;
    UIAlertController *ackAlert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [ackAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [self closeBallot];
    }]];
    [ackAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
    }]];
    [self presentViewController:ackAlert animated:YES completion:nil];
}

- (void)closeBallot {
    
    [_ballot setClosed];
    
    [_entityManager performSyncBlockAndSafe:nil];
    
    [MessageSender sendCreateMessageForBallot:_ballot];
    
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - button actions

- (void) votePressed {
    [self setDefaultResultsIfMissing];
    
    _ballot.modifyDate = [NSDate date];
    [_entityManager performSyncBlockAndSafe:nil];
    
    [MessageSender sendBallotVoteMessage:_ballot];
    
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void) ballotClosePressed {
    [self showBallotCloseAcknowledgeAlert];
}

- (void)resultsTapped {
    BallotResultViewController *viewController = [BallotResultViewController ballotResultViewControllerForBallot: _ballot];
    
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void) ballotEditPressed {
    BallotCreateViewController *viewController = [BallotCreateViewController ballotCreateViewControllerForBallot: _ballot];
    
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void) cancelPressed {
    [_entityManager rollback];
    
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - table view data source

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [Colors updateTableViewCell:cell];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0.001;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_choices count];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *title = [self choiceTextAt:indexPath.row];
    
    CGRect rect = CGRectMake(0.0, 0.0, CGRectGetWidth(_choiceTableView.frame), CGFLOAT_MAX);
    CGFloat height = [BallotVoteTableCell calculateHeightFor:title inFrame:rect];
    return height;
}

- (UITableViewCell *) tableView: (UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *title = [self choiceTextAt:indexPath.row];
    
    BallotVoteTableCell *cell = [tableView dequeueReusableCellWithIdentifier: BALLOT_VOTE_TABLE_CELL_ID];
    if (cell == nil) {
        cell = [[BallotVoteTableCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier: BALLOT_VOTE_TABLE_CELL_ID];
    }
    
    [cell.choiceLabel setText: title];
    [cell.choiceLabel sizeToFit];
    cell.frame = [RectUtil setHeightOf:cell.frame height:cell.choiceLabel.bounds.size.height];
    
    [self updateCheckmarkForCell:cell atIndexPath: indexPath];
    
    if ([_ballot isIntermediate]) {
        NSString *voteCount = [self voteCountTextAt:indexPath.row];
        [cell.voteCountLabel setText: voteCount];
    } else {
        cell.voteCountLabel.hidden = YES;
    }
    
    [self updateAccessabilityLabelForCell:cell];
    
    return cell;
}

- (void)updateAccessabilityLabelForCell:(BallotVoteTableCell *)cell {
    NSString *votesCountFormat = NSLocalizedStringFromTable(@"ballot_votes_count", @"Ballot", nil);
    NSString *selected = cell.checkmarkView.hidden ? NSLocalizedStringFromTable(@"ballot_vote_not_selected", @"Ballot", nil) : NSLocalizedStringFromTable(@"ballot_vote_selected", @"Ballot", nil);
    if (_ballot.isIntermediate) {
        NSString *votesCount = [NSString stringWithFormat:votesCountFormat, cell.voteCountLabel.text];
        cell.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@", cell.choiceLabel.text, votesCount, selected];
    } else {
        cell.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", cell.choiceLabel.text, selected];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL toggleValue = [self resultForChoiceAt:indexPath.row];
    [self setResult:!toggleValue forChoiceAt:indexPath.row];
    
    [tableView deselectRowAtIndexPath:indexPath animated: YES];
}

@end
