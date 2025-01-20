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

#import "BallotVoteViewController.h"
#import "BallotVoteTableCell.h"
#import "BallotChoice.h"
#import "MyIdentityStore.h"
#import "Ballot.h"
#import "RectUtil.h"
#import "BallotHeaderView.h"
#import "BallotCreateViewController.h"
#import "BallotResultViewController.h"
#import "UIImage+ColoredImage.h"
#import "NibUtil.h"
#import "BundleUtil.h"
#import "UserSettings.h"
#import "ThreemaFramework.h"

#define BALLOT_VOTE_TABLE_CELL_ID @"BallotVoteTableCellId"
#define BALLOT_CLOSE_ACK_MESSAGE [BundleUtil localizedStringForKey:@"ballot_close_ack"]

@interface BallotVoteViewController () <UITableViewDelegate, UITableViewDataSource>

@property NSArray *choices;
@property EntityManager *entityManager;
@property BallotManager *ballotManager;
@property Ballot *ballot;
@property bool voted;

@property BallotHeaderView *headerView;

@end

@implementation BallotVoteViewController

+ (instancetype) ballotVoteViewControllerForBallot:(Ballot *)ballot {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Ballot" bundle:nil];
    
    BallotVoteViewController *viewController = (BallotVoteViewController *) [storyboard instantiateViewControllerWithIdentifier:@"BallotVoteViewController"];
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    viewController.entityManager = entityManager;
    viewController.ballotManager = [[BallotManager alloc] initWithEntityManager:entityManager];
    viewController.ballot = (Ballot *)[entityManager.entityFetcher existingObjectWithID:ballot.objectID];
    
    return viewController;
}

-(void)viewWillLayoutSubviews {
    if (_adminView.hidden && !_summaryView.hidden) {
        _summaryView.frame = [RectUtil setYPositionOf:_summaryView.frame y:CGRectGetMaxY(self.view.frame) - CGRectGetHeight(_summaryView.frame)];
    }
    
    CGFloat top = self.view.safeAreaInsets.top;
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
        
        UIImage *tmpImage = [UIImage systemImageNamed:@"chevron.right"];
        _detailsImage.image = [tmpImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        _detailsImage.tintColor = UIColor.labelColor;
    } else {
        _detailsImage.hidden = YES;
    }
    
    [_ballotCloseButton addTarget:self action:@selector(ballotClosePressed) forControlEvents:UIControlEventTouchUpInside];
    [_ballotEditButton addTarget:self action:@selector(ballotEditPressed) forControlEvents:UIControlEventTouchUpInside];
    
    _headerView = (BallotHeaderView *)[NibUtil loadViewFromNibWithName:@"BallotHeaderView"];
    _headerView.ballot = _ballot;
    _headerView.frame = _headerPlaceholderView.bounds;
    [_headerPlaceholderView addSubview: _headerView];
    
    _voteButton.title = [BundleUtil localizedStringForKey:@"ballot_vote"];
    [_ballotCloseButton setTitle:[BundleUtil localizedStringForKey:@"ballot_close"] forState:UIControlStateNormal];
    
    [self setupColors];
}

- (void)refresh {
    [super refresh];
}

- (void)setupColors {
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    
    _adminView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    
    _summaryView.backgroundColor = UIColor.systemFillColor;
    _countVotesLabel.textColor = UIColor.labelColor;
        
    _headerPlaceholderView.backgroundColor = UIColor.systemBackgroundColor;
    
    _detailsImage.tintColor = UIColor.labelColor;
}

- (void)updateContent {
    _choices = [_ballot choicesSortedByOrder];
    
    [self setTitle:[BundleUtil localizedStringForKey:@"ballot"]];
    
    if (_ballot.conversation == nil) {
        _voteButton.enabled = NO;
    }

    GroupManager *groupManager = [[[BusinessInjector alloc] initWithEntityManager:_entityManager] groupManagerObjC];
    MessagePermission *messagePermission = [[MessagePermission alloc] initWithMyIdentityStore:[MyIdentityStore sharedMyIdentityStore] userSettings:[UserSettings sharedUserSettings] groupManager:groupManager entityManager:_entityManager];

    Group *group = [groupManager getGroupWithConversation:_ballot.conversation];
    if (group) {
        _voteButton.enabled = [messagePermission canSendWithGroupID:group.groupID groupCreatorIdentity:group.groupCreatorIdentity reason:nil];
    }
    else {
        _voteButton.enabled = _ballot.conversation.contact && [messagePermission canSendTo:_ballot.conversation.contact.identity reason:nil];
    }

    NSString *messageFormat = [BundleUtil localizedStringForKey:@"ballot_got_votes_count"];
    NSInteger countParticipants = _ballot.conversationParticipantsCount;
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
    
    [_ballotManager updateOwnChoice:choice with:[NSNumber numberWithBool:value]];

    self.voted = true;
    
    [self updateTable];
}

- (BOOL)resultForChoiceAt:(NSInteger)index {
    BallotChoice *choice = [_choices objectAtIndex:index];
    
    BallotResultEntity *result = [choice getOwnResult];
    if (result) {
        return result.boolValue;
    }
    
    return NO;
}

- (void)resetAllValues {
    for (BallotChoice *choice in _choices) {
        [_ballotManager updateOwnChoice:choice with:[NSNumber numberWithBool:NO]];
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
        
        NSString *title = [BundleUtil localizedStringForKey:@"ballot_vote_ballot_closed_title"];
        NSString *message = [BundleUtil localizedStringForKey:@"ballot_vote_ballot_closed_message"];
        [UIAlertTemplate showAlertWithOwner:self title:title message:message actionOk:nil];
    }
}

- (void)setDefaultResultsIfMissing {
    for (BallotChoice *choice in [_ballot choices]) {
        if ([choice getOwnResult] == nil) {
            // Add default value
            [_ballotManager updateOwnChoice:choice with:[NSNumber numberWithBool:NO]];
        }
    }
}

- (void)showBallotCloseAcknowledgeAlert {
    NSString *title = [BundleUtil localizedStringForKey:@"ballot_close"];
    NSString *message = BALLOT_CLOSE_ACK_MESSAGE;
    UIAlertController *ackAlert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [ackAlert addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"ok"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * action) {
        [self closeBallot];
    }]];
    [ackAlert addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"cancel"] style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ackAlert animated:YES completion:nil];
}

- (void)closeBallot {
    
    [_ballot setClosed];
    
    [_entityManager performSyncBlockAndSafe:nil];

    MessageSender *messageSender = [[[BusinessInjector alloc] initWithEntityManager:_entityManager] messageSenderObjC];
    [messageSender sendBallotMessageFor:_ballot];
    
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - button actions

- (void) votePressed {
    [self setDefaultResultsIfMissing];
    
    _ballot.modifyDate = [NSDate date];
    [_entityManager performSyncBlockAndSafe:nil];
    
    MessageSender *messageSender = [[[BusinessInjector alloc] initWithEntityManager:_entityManager] messageSenderObjC];
    [messageSender sendBallotVoteMessageFor:_ballot];
    
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
    if (self.voted) {
        NSString *title = [BundleUtil localizedStringForKey:@"voteCancelTitle"];
        NSString *message = [BundleUtil localizedStringForKey:@"voteCancelMessage"];
        NSString *destructiveTitle = [BundleUtil localizedStringForKey:@"discardVoteTitle"];
        NSString *cancelTitle = [BundleUtil localizedStringForKey:@"cancel"];
        
        [UIAlertTemplate showDestructiveAlertWithOwner:self title:title message:message titleDestructive:destructiveTitle actionDestructive:^(UIAlertAction * _Nonnull __unused destructiveAction) {
            [self discardAndClose];
        } titleCancel:cancelTitle actionCancel:^(UIAlertAction * _Nonnull __unused cancelAction) {
            // Do nothing and allow casting the vote
        }];
    } else {
        [self discardAndClose];
    }
}

- (void)discardAndClose {
    // Close the dialogue and discard the vote
    [_entityManager rollback];
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - table view data source

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
    NSString *votesCountFormat = [BundleUtil localizedStringForKey:@"ballot_votes_count"];
    NSString *selected = cell.checkmarkView.hidden ? [BundleUtil localizedStringForKey:@"ballot_vote_not_selected"] : [BundleUtil localizedStringForKey:@"ballot_vote_selected"];
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
