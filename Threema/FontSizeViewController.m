//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2020 Threema GmbH
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

#import "FontSizeViewController.h"
#import "UserSettings.h"

@interface FontSizeViewController ()

@end

@implementation FontSizeViewController {
    NSIndexPath *selectedIndexPath;
}

static int fontSizes[] = {12, 14, 16, 18, 20, 24, 28, 30, 36};

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (sizeof(fontSizes) / sizeof(int) + 1);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"FontSizeCell"];
    
    if (indexPath.row == sizeof(fontSizes) / sizeof(int)) {
        UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleBody];
        cell.textLabel.font = [UIFont systemFontOfSize:fontDescriptor.pointSize];
        cell.textLabel.text = NSLocalizedString(@"use_dynamic_font_size", @"");
        if ([[UserSettings sharedUserSettings] useDynamicFontSize]) {
            selectedIndexPath = indexPath;
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else {
        cell.textLabel.font = [UIFont systemFontOfSize:fontSizes[indexPath.row]];
        cell.textLabel.text = [NSString stringWithFormat:@"%d %@", fontSizes[indexPath.row], NSLocalizedString(@"font_point", @"")];
        
        if (roundf([UserSettings sharedUserSettings].chatFontSize) == fontSizes[indexPath.row] && ![[UserSettings sharedUserSettings] useDynamicFontSize]) {
            selectedIndexPath = indexPath;
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == sizeof(fontSizes) / sizeof(int)) {
        [UserSettings sharedUserSettings].useDynamicFontSize = YES;
    } else {
        [UserSettings sharedUserSettings].chatFontSize = fontSizes[indexPath.row];
        [UserSettings sharedUserSettings].useDynamicFontSize = NO;
    }
    if (selectedIndexPath != nil)
        [self.tableView cellForRowAtIndexPath:selectedIndexPath].accessoryType = UITableViewCellAccessoryNone;
    
    [self.tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    selectedIndexPath = indexPath;
}

@end
