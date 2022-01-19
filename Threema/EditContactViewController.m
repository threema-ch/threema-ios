//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2022 Threema GmbH
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

#import <ThreemaFramework/Constants.h>
#import "EditContactViewController.h"
#import "Contact.h"
#import "EntityManager.h"
#import "AvatarMaker.h"
#import "AppDelegate.h"
#import "ModalPresenter.h"
#import "ProtocolDefines.h"
#import "UIDefines.h"
#import "UIImage+Resize.h"
#import "BundleUtil.h"
#import "UserSettings.h"

@interface EditContactViewController () <EditableAvatarViewDelegate, UITextFieldDelegate>

@end

@implementation EditContactViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _avatarView.presentingViewController = self;
    _avatarView.delegate = self;
    _avatarView.canChooseImage = YES;
    
    _firstNameTextField.delegate = self;
    _lastNameTextField.delegate = self;
    
    [self setupColors];
    
    self.tableView.rowHeight = 100.0;
    self.tableView.estimatedRowHeight = 100.0;
}

- (void)setupColors {
    [Colors updateKeyboardAppearanceFor:self.firstNameTextField];

    [Colors updateKeyboardAppearanceFor:self.lastNameTextField];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self updateView];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[[EntityManager alloc] init] performSyncBlockAndSafe:^{
        if (_firstNameTextField.text.length > 0) {
            _contact.firstName = _firstNameTextField.text;
        } else {
            _contact.firstName = nil;
        }
        
        if (_lastNameTextField.text.length > 0) {
            _contact.lastName = _lastNameTextField.text;
        } else {
            _contact.lastName = nil;
        }
    }];
    
    [super viewWillDisappear:animated];
}

- (void)updateView {
    if (_contact.contactImage && [UserSettings sharedUserSettings].showProfilePictures) {
        _avatarView.imageData = _contact.contactImage.data;
        _avatarView.isReceivedImage = YES;
        _avatarView.canDeleteImage = NO;
    } else if (_contact.imageData) {
        _avatarView.imageData = _contact.imageData;
        _avatarView.isReceivedImage = NO;
        _avatarView.canDeleteImage = YES;
    }
    
    _firstNameTextField.text = _contact.firstName;
    _lastNameTextField.text = _contact.lastName;
    
    if (_firstNameTextField.text.length < 1) {
        [_firstNameTextField becomeFirstResponder];
    }
}

- (BOOL)resignFirstResponder {
    [_firstNameTextField resignFirstResponder];
    [_lastNameTextField resignFirstResponder];
    
    return YES;
}


#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.tableView.rowHeight;
}

-(CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.tableView.rowHeight;
}

#pragma mark - Avatar delegate

- (void)avatarImageUpdated:(NSData *)newImageData {
    if (newImageData == nil) {
        _avatarView.canDeleteImage = NO;
        if (_contact.contactImage)
            _avatarView.imageData = _contact.contactImage.data;
    }
    
    if (newImageData == _contact.imageData) {
        return;
    }
    
    [[[EntityManager alloc] init] performSyncBlockAndSafe:^{
        _contact.imageData = newImageData;
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSUInteger bytes = [textField.text lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (bytes > 256 && ![string isEqualToString:@""]) {
        return NO;
    }
    return YES;
}


@end
