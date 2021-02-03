//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2021 Threema GmbH
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

#import "VideoQualityViewController.h"
#import "MediaConverter.h"
#import "UserSettings.h"

@interface VideoQualityViewController ()

@end

@implementation VideoQualityViewController {
    NSIndexPath *selectedIndexPath;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.tableView reloadData];
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [MediaConverter videoQualities].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"VideoQualityCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    NSString *quality = [MediaConverter videoQualities][indexPath.row];
    cell.textLabel.text = NSLocalizedString(quality, nil);
    NSNumber *maxDuration = [MediaConverter videoQualityMaxDurations][indexPath.row];
    if (maxDuration.intValue == 1)
        cell.detailTextLabel.text = NSLocalizedString(@"max_1_minute", nil);
    else
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"max_x_minutes", nil), maxDuration.intValue];
    
    if ([[UserSettings sharedUserSettings].videoQuality isEqualToString:quality]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        selectedIndexPath = indexPath;
    } else
        cell.accessoryType = UITableViewCellAccessoryNone;
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [UserSettings sharedUserSettings].videoQuality = [MediaConverter videoQualities][indexPath.row];
    
    if (selectedIndexPath != nil)
        [self.tableView cellForRowAtIndexPath:selectedIndexPath].accessoryType = UITableViewCellAccessoryNone;
    
    [self.tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    selectedIndexPath = indexPath;
}

@end
