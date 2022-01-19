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

@interface ThemedTableViewController ()

@end

@implementation ThemedTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupForColorTheme];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDynamicTypeChange:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callInBackgroundTimeChanged:) name:kNotificationCallInBackgroundTimeChanged object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    self.navigationItem.prompt = [[VoIPHelper shared] currentPromtString:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)refresh {
    [self setupForColorTheme];
    
    [self.tableView reloadData];
}

- (void)setupForColorTheme {
    [self.view setBackgroundColor:[Colors background]];
    
    [Colors updateTableView:self.tableView];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:[UITableViewCell class]]) {
        [Colors updateTableViewCell:cell];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(nonnull UIView *)view forSection:(NSInteger)section {
    [self colorizeHeaderFooterView:view];
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
    [self colorizeHeaderFooterView:view];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

- (void)colorizeHeaderFooterView:(UIView *)view {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *headerView = (UITableViewHeaderFooterView*)view;
        [headerView.contentView setBackgroundColor:[Colors backgroundDark]];
        [headerView.textLabel setTextColor:[Colors fontLight]];
    }
}

- (void)handleDynamicTypeChange:(NSNotification *)theNotification {
    [self refresh];
}

- (void)callInBackgroundTimeChanged:(NSNotification*)notification {
    NSNumber *time = notification.object;
    self.navigationItem.prompt = [[VoIPHelper shared] currentPromtString:time];
    
    if (self.navigationItem.prompt == nil) {
        if ([self respondsToSelector:@selector(updateLayoutAfterCall)]) {
            double delayInSeconds = 0.3;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self performSelector:@selector(updateLayoutAfterCall)];
            });
        }
    }
}

- (void)updateLayoutAfterCall {
    // do nothing
}

@end
