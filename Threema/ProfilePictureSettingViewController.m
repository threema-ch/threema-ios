//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2020 Threema GmbH
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

#import "ProfilePictureSettingViewController.h"
#import "UserSettings.h"
#import "PickContactsViewController.h"
#import "ModalPresenter.h"

@interface ProfilePictureSettingViewController ()

@end

@implementation ProfilePictureSettingViewController {
    NSIndexPath *selectedIndexPath;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
}

#pragma mark - Private functions

- (NSString *)getLabelForSendProfilePicture:(enum SendProfilePicture)sendProfilePicture {
    switch (sendProfilePicture) {
        case 0:
            return NSLocalizedString(@"send_profileimage_off", nil);
        case 1:
            return NSLocalizedString(@"send_profileimage_on", nil);
        case 2:
            return NSLocalizedString(@"send_profileimage_contacts", nil);
        default:
            return nil;
    }
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if ([UserSettings sharedUserSettings].sendProfilePicture == SendProfilePictureContacts) {
        return 2;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 1)
        return 1;
    else
        return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"ProfilePictureSettingCell"];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textColor = [Colors fontNormal];
        
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = [self getLabelForSendProfilePicture:SendProfilePictureNone];
                if ([UserSettings sharedUserSettings].sendProfilePicture == SendProfilePictureNone) {
                    cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    selectedIndexPath = indexPath;
                }
                break;
            case 1:
                cell.textLabel.text = [self getLabelForSendProfilePicture:SendProfilePictureAll];
                if ([UserSettings sharedUserSettings].sendProfilePicture == SendProfilePictureAll) {
                    cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    selectedIndexPath = indexPath;
                }
                break;
            case 2:
                cell.textLabel.text = [self getLabelForSendProfilePicture:SendProfilePictureContacts];
                if ([UserSettings sharedUserSettings].sendProfilePicture == SendProfilePictureContacts) {
                    cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    selectedIndexPath = indexPath;
                }
                break;
            default:
                break;
        }
        
        return cell;
    } else {
        UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"SendProfilePictureContactsCell"];
        cell.textLabel.textColor = [Colors fontNormal];
        return cell;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0 && [UserSettings sharedUserSettings].sendProfilePicture == SendProfilePictureAll) {
        return NSLocalizedString(@"profileimage_setting_all_footer", nil);
    }
    else if (section == 1) {
        return NSLocalizedString(@"profileimage_setting_contacts_footer", nil);
    }
    
    return nil;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
                [[UserSettings sharedUserSettings] setSendProfilePicture:SendProfilePictureNone];
                break;
            case 1:
                [[UserSettings sharedUserSettings] setSendProfilePicture:SendProfilePictureAll];
                break;
            case 2:
                [[UserSettings sharedUserSettings] setSendProfilePicture:SendProfilePictureContacts];
                break;
            default:
                break;
        }
        
        BOOL shouldShowPicker = indexPath.row == 2 && selectedIndexPath.row != 2;
        
        [self.tableView beginUpdates];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        if (shouldShowPicker) {
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
        }
        else if (selectedIndexPath.row == 2 && indexPath.row != 2) {
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
        }
        [self.tableView endUpdates];
        
        selectedIndexPath = indexPath;
        
        if (shouldShowPicker) {
            UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"ProfilePicture" bundle:nil];
            PickContactsViewController *pickContactsVC = [storyboard instantiateViewControllerWithIdentifier:@"PickContactsViewController"];
            
            UINavigationController *navigationVC = [[UINavigationController alloc] initWithRootViewController:pickContactsVC];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            [ModalPresenter present:navigationVC on:self fromRect:cell.frame inView:self.view];
        }
    } else {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"ProfilePicture" bundle:nil];
        PickContactsViewController *pickContactsVC = [storyboard instantiateViewControllerWithIdentifier:@"PickContactsViewController"];
        
        UINavigationController *navigationVC = [[UINavigationController alloc] initWithRootViewController:pickContactsVC];
        if (@available(iOS 11.0, *)) {
            navigationVC.navigationBar.prefersLargeTitles = NO;
        }
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        [ModalPresenter present:navigationVC on:self fromRect:cell.frame inView:self.view];
        if (SYSTEM_IS_IPAD) {
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
    }
}

@end
