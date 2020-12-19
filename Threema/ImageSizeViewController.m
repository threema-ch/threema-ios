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

#import "ImageSizeViewController.h"
#import "UserSettings.h"
#import "BundleUtil.h"

@interface ImageSizeViewController ()

@end

@implementation ImageSizeViewController {
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
    
    [self.tableView footerViewForSection:0].textLabel.preferredMaxLayoutWidth = [self.tableView footerViewForSection:0].textLabel.frame.size.width;
    [self.tableView footerViewForSection:0].textLabel.numberOfLines = 0;

    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
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

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    
    [cell.detailTextLabel setTextColor:[Colors fontLight]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [ImageURLSenderItemCreator getImageSizeNo];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ImageSizeCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    NSString *size = (NSString *)[ImageURLSenderItemCreator imageSizes][indexPath.row];
    cell.textLabel.text = NSLocalizedString(size, nil);
    
    NSNumber *pixels = (NSNumber *)[ImageURLSenderItemCreator imagePixelSizes][indexPath.row];
    if (pixels.intValue == 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"images are not scaled", nil)];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"max_x_by_x_pixels", nil), pixels, pixels];
    }
    
    if ([[UserSettings sharedUserSettings].imageSize isEqualToString:size]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        selectedIndexPath = indexPath;
    } else
        cell.accessoryType = UITableViewCellAccessoryNone;
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (selectedIndexPath.row == 3 || selectedIndexPath.row == 4) {
        return [BundleUtil localizedStringForKey:@"image_resize_share_extension"];
    }
    return @"";
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [UserSettings sharedUserSettings].imageSize = [ImageURLSenderItemCreator imageSizes][indexPath.row];
    
    if (selectedIndexPath != nil)
        [self.tableView cellForRowAtIndexPath:selectedIndexPath].accessoryType = UITableViewCellAccessoryNone;

    [self.tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    selectedIndexPath = indexPath;
    
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
}

@end
