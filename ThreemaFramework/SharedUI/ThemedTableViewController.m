//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2022 Threema GmbH
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

#import "ThemedTableViewController.h"
#import "VoIPHelper.h"
#import "ThreemaFramework/ThreemaFramework-swift.h"

@interface ThemedTableViewController ()

@end

@implementation ThemedTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self updateColors];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDynamicTypeChange:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(navigationItemPromptShouldChange:) name:kNotificationNavigationItemPromptShouldChange object:nil];
    
    if (self.tableView.style == UITableViewStyleGrouped) {
        self.tableView.estimatedSectionHeaderHeight = 38;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.view.backgroundColor = Colors.backgroundView;
    
    self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    NSString *callPrompt = [[VoIPHelper shared] currentPromptString:nil];
    if (callPrompt == nil && [WCSessionHelper isWCSessionConnected]) {
        callPrompt = WCSessionHelper.threemaWebPrompt;
    }
    self.navigationItem.prompt = callPrompt;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)refresh {
    [self updateColors];
    
    [self.tableView reloadData];
}

- (void)updateColors {        
    [Colors updateWithTableView:self.tableView];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [Colors updateWithCell:cell setBackgroundColor:true];
    
    if ([cell respondsToSelector:@selector(updateColors)]) {
        [cell performSelector:@selector(updateColors)];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (void)handleDynamicTypeChange:(NSNotification *)theNotification {
    [self refresh];
}

- (void)navigationItemPromptShouldChange:(NSNotification*)notification {
    NSNumber *time = notification.object;
    NSString *callPrompt = [[VoIPHelper shared] currentPromptString:time];
    if (callPrompt == nil && [WCSessionHelper isWCSessionConnected]) {
        callPrompt = WCSessionHelper.threemaWebPrompt;
    }
    self.navigationItem.prompt = callPrompt;
    
    if (self.navigationItem.prompt == nil) {
        if ([self respondsToSelector:@selector(updateLayoutAfterCall)]) {
            double delayInSeconds = 0.3;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self performSelector:@selector(updateLayoutAfterCall)];
            });
        }
    }
    [self.navigationController.view setNeedsLayout];
    [self.navigationController.view layoutIfNeeded];
    [self.navigationController.view setNeedsDisplay];
}

- (void)updateLayoutAfterCall {
    // do nothing
}

@end
