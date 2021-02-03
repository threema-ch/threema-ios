//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2021 Threema GmbH
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

#import "SyncExclusionListViewController.h"
#import "UserSettings.h"
#import "ProtocolDefines.h"
#import "UIImage+ColoredImage.h"

@interface SyncExclusionListViewController ()

@end

@implementation SyncExclusionListViewController {
    NSArray *syncExclusionList;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    syncExclusionList = [UserSettings sharedUserSettings].syncExclusionList;
    
    [self.tableView reloadData];
}

- (void)saveToSettings {
    [UserSettings sharedUserSettings].syncExclusionList = syncExclusionList;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return syncExclusionList.count+1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < syncExclusionList.count) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ExclusionCell"];
        cell.textLabel.text = [syncExclusionList objectAtIndex:indexPath.row];
        return cell;
    } else {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AddCell"];
        cell.imageView.image = [UIImage imageNamed:@"AddMember" inColor:[Colors main]];
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSMutableArray *newArray = [NSMutableArray arrayWithArray:syncExclusionList];
        [newArray removeObjectAtIndex:indexPath.row];
        syncExclusionList = newArray;
        [self saveToSettings];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0)
        return NSLocalizedString(@"sync_exclusion_footer", nil);
    
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == syncExclusionList.count) {
        /* add cell */
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"enter_id_to_exclude", nil) message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        }];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ok", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
            
            NSString *excludeId = [[alert.textFields objectAtIndex:0].text uppercaseString];
            if (excludeId.length == kIdentityLen) {
                NSMutableSet *newSet = [NSMutableSet setWithArray:syncExclusionList];
                [newSet addObject:excludeId];
                syncExclusionList = [[newSet allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
                [self saveToSettings];
                
                [self.tableView reloadData];
            }
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
            [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < syncExclusionList.count)
        return YES;
    
    return NO;
}

@end
