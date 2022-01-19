//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2017-2022 Threema GmbH
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

#import <MobileCoreServices/UTCoreTypes.h>

#import "EditProfileViewController.h"
#import "AvatarMaker.h"
#import "AppDelegate.h"
#import "ModalPresenter.h"
#import "ProtocolDefines.h"
#import "UIDefines.h"
#import "UIImage+Resize.h"
#import "BundleUtil.h"
#import "MyIdentityStore.h"
#import "EntityManager.h"
#import "ContactStore.h"
#import "UserSettings.h"
#import "PickContactsViewController.h"
#import "LicenseStore.h"
#import "ValidationLogger.h"
#import "MDMSetup.h"

@interface EditProfileViewController () <EditableAvatarViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) NSIndexPath *indexPathForPicker;

@end

@implementation EditProfileViewController {
    MDMSetup *mdmSetup;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        mdmSetup = [[MDMSetup alloc] initWithSetup:NO];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _avatarView.presentingViewController = self;
    _avatarView.delegate = self;
    _avatarView.canDeleteImage = ![mdmSetup readonlyProfile];
    _avatarView.canChooseImage = ![mdmSetup readonlyProfile];

    _profileCell.contentView.isAccessibilityElement = NO;
    _profileCell.contentView.accessibilityLabel = nil;
    
    _nickNameTextField.delegate = self;
    
    [self setupColors];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self updateView];
    
    _indexPathForPicker = nil;
    
    _profilePictureSettingCell.userInteractionEnabled = ![mdmSetup disableSendProfilePicture];
    
    if ([mdmSetup readonlyProfile]) {
        _nickNameTextField.enabled = NO;
    } else {
        if(!UIAccessibilityIsVoiceOverRunning()) {
            [_nickNameTextField becomeFirstResponder];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    NSString *newNickname = _nickNameTextField.text;
    if (newNickname.length == 0) {
        newNickname = nil;
    }
    [MyIdentityStore sharedMyIdentityStore].pushFromName = newNickname;
    [[LicenseStore sharedLicenseStore] performUpdateWorkInfo];
    
    [_nickNameTextField resignFirstResponder];
}

#pragma mark - Private functions

- (void)setupColors {
    [Colors updateKeyboardAppearanceFor:self.nickNameTextField];
    
    [_nickNameTitleLabel setTextColor:[Colors fontVeryLight]];
    _nickNameTitleLabel.shadowColor = nil;
}

- (void)updateView {
    NSMutableDictionary *profile = [[MyIdentityStore sharedMyIdentityStore] profilePicture];
    NSData *data = profile[@"ProfilePicture"];
    
    if (data) {
        _avatarView.imageData = data;
        _avatarView.canDeleteImage = ![mdmSetup readonlyProfile];
    } else {
        _avatarView.imageData = nil;
        _avatarView.canDeleteImage = NO;
    }
    
    _nickNameTextField.text = [[MyIdentityStore sharedMyIdentityStore] pushFromName];
    _nickNameTextField.placeholder = [MyIdentityStore sharedMyIdentityStore].identity;
    _nickNameTextField.accessibilityLabel = NSLocalizedString(@"id_completed_nickname", @"");
    
    _contactsSettingValue.text = [self getLabelForSendProfilePicture:[UserSettings sharedUserSettings].sendProfilePicture];
    
    [self disabledCellsForMDM];
}

- (BOOL)resignFirstResponder {
    [_nickNameTextField resignFirstResponder];
    
    return YES;
}

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

- (void)disabledCellsForMDM {
    // isReadonlyProfile
    self.profilePictureSettingCell.userInteractionEnabled = ![mdmSetup disableSendProfilePicture];
    self.profilePictureSettingCell.textLabel.enabled = ![mdmSetup disableSendProfilePicture];
}

#pragma mark - UITableViewDelegates

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [Colors updateTableViewCell:cell];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSMutableString *footer = [NSMutableString stringWithString:NSLocalizedString(@"edit_profile_footer", nil)];
    
    
    if ([mdmSetup readonlyProfile] || [mdmSetup disableSendProfilePicture]) {
        [footer appendString:@"\n\n"];
        [footer appendString:NSLocalizedString(@"disabled_by_device_policy", nil)];
    }
    
    return footer;
}

#pragma mark - Avatar delegate

- (void)avatarImageUpdated:(NSData *)newImageData {
    [[AvatarMaker sharedAvatarMaker] clearCacheForProfilePicture];
    if (newImageData == nil) {
        _avatarView.canDeleteImage = NO;
    }
    
    NSMutableDictionary *profile = [[MyIdentityStore sharedMyIdentityStore] profilePicture];
    if (newImageData == profile[@"ProfilePicture"]) {
        return;
    }
    if (!profile)
        profile = [NSMutableDictionary new];
    [profile setValue:newImageData forKey:@"ProfilePicture"];
    [profile removeObjectForKey:@"LastUpload"];
    [[MyIdentityStore sharedMyIdentityStore] setProfilePicture:profile];
    
    [[ContactStore sharedContactStore] removeProfilePictureFlagForAllContacts];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSUInteger bytes = [textField.text lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (bytes > 32 && ![string isEqualToString:@""]) {
        return NO;
    }
    return YES;
}


@end
