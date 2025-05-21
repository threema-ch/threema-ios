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

#import "BallotCreateDetailViewController.h"
#import "BallotSelectTableViewController.h"
#import "BundleUtil.h"
@interface BallotCreateDetailViewController ()

@end

static NSData *ballotIdForAcceptedWarning;

@implementation BallotCreateDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self updateUIStrings];
    
    [self updateContent];
    
    [_showIntermediateSwitch addTarget:self action:@selector(intermediateUpdated) forControlEvents:UIControlEventValueChanged];
    [_multipleChoiceSwitch addTarget:self action:@selector(multipleChoiceUpdated) forControlEvents:UIControlEventValueChanged];
    
    [_cloneButton addTarget:self action:@selector(clonePressed) forControlEvents:UIControlEventTouchUpInside];
}

- (void)viewWillAppear:(BOOL)animated {
    [self updateContent];
    
    [super viewWillAppear:animated];
}

- (void)updateUIStrings {
    [_showIntermediateLabel setText:[BundleUtil localizedStringForKey:@"ballot_show_intermediate_results"]];
    [_multipleChoiceLabel setText:[BundleUtil localizedStringForKey:@"ballot_multiple_choice"]];
    
    [_cloneButton setTitle:[BundleUtil localizedStringForKey:@"ballot_clone"] forState:UIControlStateNormal];
    
    [self setTitle:[BundleUtil localizedStringForKey:@"ballot_options"]];
}

- (void)updateContent {
    [_entityManager performBlockAndWait:^{
        _showIntermediateSwitch.on = [_ballot isIntermediate];
        _multipleChoiceSwitch.on = [_ballot isMultipleChoice];
    }];
}

- (void)intermediateUpdated {
    [_entityManager performBlockAndWait:^{
        if (_showIntermediateSwitch.on) {
            _ballot.type = [NSNumber numberWithInt:BallotTypeIntermediate];
        }
        else {
            _ballot.type = [NSNumber numberWithInt:BallotTypeClosed];
        }
    }];
}

- (void)multipleChoiceUpdated {
    [_entityManager performBlockAndWait:^{
        if (_showIntermediateSwitch.on) {
            _ballot.assessmentType = [NSNumber numberWithInt:BallotAssessmentTypeMulti];
        }
        else {
            _ballot.assessmentType = [NSNumber numberWithInt:BallotAssessmentTypeSingle];
        }
    }];
}

- (void)showCloneWarning {
    NSString *title = [BundleUtil localizedStringForKey:@"ballot_clone_warning_title"];
    NSString *message = [BundleUtil localizedStringForKey:@"ballot_clone_warning_message"];
    
    UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [errAlert addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"ok"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction * action) {
        [self performSegueWithIdentifier:@"ballotCloneSegue" sender:self];
    }]];
    [errAlert addAction:[UIAlertAction actionWithTitle:[BundleUtil localizedStringForKey:@"cancel"] style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:errAlert animated:YES completion:nil];
}

- (BOOL)ballotHasData {
    if ([_ballot.title length] > 0) {
        return YES;
    }
    
    for (BallotChoiceEntity *choice in _ballot.choices) {
        if ([choice.name length] > 0) {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - button actions

-(void)clonePressed {
    __block NSData *ballotId;

    [_entityManager performBlockAndWait:^{
        ballotId = _ballot.id;
    }];

    if ([ballotIdForAcceptedWarning isEqualToData:ballotId]) {
        ; //noop
    } else if ([self ballotHasData]) {
        [self showCloneWarning];
    }
    
    [self performSegueWithIdentifier:@"ballotCloneSegue" sender:self];
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ballotCloneSegue"]) {
        [_entityManager performBlock:^{
            ballotIdForAcceptedWarning = _ballot.id;
            BallotSelectTableViewController *controller = (BallotSelectTableViewController*)segue.destinationViewController;
            controller.ballot = _ballot;
            controller.entityManager = _entityManager;
        }];
    }
}

#pragma mark - Table view data source

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1)
        return [BundleUtil localizedStringForKey:@"ballot_description_intermediate"];
    else if (section == 2)
        return [BundleUtil localizedStringForKey:@"ballot_description_multiplechoice"];
    
    return nil;
}

@end
