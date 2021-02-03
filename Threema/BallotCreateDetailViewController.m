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

#import "BallotCreateDetailViewController.h"
#import "BallotSelectTableViewController.h"
#import "BallotChoice.h"

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
    
    [self setupColors];
}

- (void)setupColors {
    [_cloneButton setTitleColor:[Colors main] forState:UIControlStateNormal];

    _multipleChoiceLabel.textColor = [Colors fontNormal];
    _showIntermediateLabel.textColor = [Colors fontNormal];
}

- (void)viewWillAppear:(BOOL)animated {
    [self updateContent];
    
    [super viewWillAppear:animated];
}

- (void)updateUIStrings {
    [_showIntermediateLabel setText:NSLocalizedStringFromTable(@"ballot_show_intermediate_results", @"Ballot", nil)];
    [_multipleChoiceLabel setText:NSLocalizedStringFromTable(@"ballot_multiple_choice", @"Ballot", nil)];
    
    [_cloneButton setTitle:NSLocalizedStringFromTable(@"ballot_clone", @"Ballot", nil) forState:UIControlStateNormal];
    
    [self setTitle:NSLocalizedStringFromTable(@"ballot_options", @"Ballot", nil)];
}

- (void)updateContent {
    _showIntermediateSwitch.on = [_ballot isIntermediate];
    _multipleChoiceSwitch.on = [_ballot isMultipleChoice];
}

- (void)intermediateUpdated {
    [_ballot setIntermediate: _showIntermediateSwitch.on];
}

- (void)multipleChoiceUpdated {
    [_ballot setMultipleChoice: _multipleChoiceSwitch.on];
}

- (void)showCloneWarning {
    NSString *title = NSLocalizedStringFromTable(@"ballot_clone_warning_title", @"Ballot", nil);
    NSString *message = NSLocalizedStringFromTable(@"ballot_clone_warning_message", @"Ballot", nil);
    
    UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [errAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [self performSegueWithIdentifier:@"ballotCloneSegue" sender:self];
    }]];
    [errAlert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
    }]];
    [self presentViewController:errAlert animated:YES completion:nil];
}

- (BOOL)ballotHasData {
    if ([_ballot.title length] > 0) {
        return YES;
    }
    
    for (BallotChoice *choice in _ballot.choices) {
        if ([choice.name length] > 0) {
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - button actions

-(void)clonePressed {
    if ([ballotIdForAcceptedWarning isEqualToData:_ballot.id]) {
        ;//nop
    } else if ([self ballotHasData]) {
        [self showCloneWarning];
        return;
    }
    
    [self performSegueWithIdentifier:@"ballotCloneSegue" sender:self];
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ballotCloneSegue"]) {
        ballotIdForAcceptedWarning = _ballot.id;
        
        BallotSelectTableViewController *controller = (BallotSelectTableViewController*)segue.destinationViewController;
        controller.ballot = _ballot;
    }
}

#pragma mark - Table view data source

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1)
        return NSLocalizedStringFromTable(@"ballot_description_intermediate", @"Ballot", nil);
    else if (section == 2)
        return NSLocalizedStringFromTable(@"ballot_description_multiplechoice", @"Ballot", nil);
    
    return nil;
}

@end
