//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2024 Threema GmbH
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

#import <ThreemaFramework/ThreemaFramework.h>

#import "Old_EditGroupViewController.h"
#import "AvatarMaker.h"
#import "AppDelegate.h"
#import "ModalPresenter.h"
#import "UIDefines.h"
#import "UIImage+Resize.h"
#import "GroupPhotoSender.h"
#import "CreateGroupNavigationController.h"
#import "ContactStore.h"
#import "EntityFetcher.h"
#import "ImageData.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface Old_EditGroupViewController () <EditableAvatarViewDelegate, UITextFieldDelegate>

@property NSString *groupName;
@property NSData *avatarImageData;

@end

@implementation Old_EditGroupViewController {
    GroupManager *groupManager;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self->groupManager = [[BusinessInjector new] groupManagerObjC];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _avatarView.presentingViewController = self;
    _avatarView.delegate = self;
    _avatarView.canDeleteImage = YES;
    _avatarView.canChooseImage = YES;

    _nameTextField.delegate = self;
    _nameTextField.placeholder = [BundleUtil localizedStringForKey:@"group name"];
    
    [Colors updateKeyboardAppearanceFor:self.nameTextField];
    
    if ([self.navigationController isKindOfClass:[CreateGroupNavigationController class]]) {
        NSData *cloneGroupId = ((CreateGroupNavigationController *)self.navigationController).cloneGroupId;
        NSString *cloneGroupCreator = ((CreateGroupNavigationController *)self.navigationController).cloneGroupCreator;
        if (cloneGroupId) {
            EntityManager *entityManager = [[EntityManager alloc] init];
            Conversation *conversation = [entityManager.entityFetcher conversationForGroupId:cloneGroupId creator:cloneGroupCreator];
            
            if (conversation) {
                _nameTextField.text = conversation.groupName;
                if (conversation.groupImage.data) {
                    _avatarView.imageData = conversation.groupImage.data;
                    _avatarImageData = conversation.groupImage.data;
                }
            }
        }
    }
}

- (void)setGroup:(Group *)group {
    _group = group;
    
    _groupName = _group.name;
    
    if (_group.profilePicture) {
        _avatarImageData = _group.profilePicture;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    
    [self updateView];
    
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self triggerNameUpdate];

    [self triggerAvatarImageUpdate];

    [super viewWillDisappear:animated];
}

- (BOOL)changedName {
    if ([_nameTextField.text isEqualToString:_group.name]) {
        return NO;
    }
    
    return YES;
}

- (BOOL)changedImage {
    if (_group.profilePicture == _avatarImageData) {
        return NO;
    }
    
    return YES;
}

- (void)triggerNameUpdate {
    if ([self changedName]) {
        if (self.nameTextField.text.length > 0) {
            [_delegate group:_group updatedName:self.nameTextField.text];
        } else {
            [_delegate group:_group updatedName:nil];
        }
    };
    
}

- (void)triggerAvatarImageUpdate {
    if ([self changedImage]) {
        [_delegate group:_group updatedImage:_avatarImageData];
    };
}

- (void)updateView {
    if (_group) {
        self.title = [BundleUtil localizedStringForKey:@"edit group"];
     
        _nameTextField.text = _groupName;
        
        if (_group.profilePicture) {
            _avatarView.imageData = _avatarImageData;
        }
    } else {
        self.title = [BundleUtil localizedStringForKey:@"new group"];
        
        BOOL hasName = self.nameTextField.text.length > 0;
        [self.navigationItem.rightBarButtonItem setEnabled:hasName];
    }
}

- (BOOL)resignFirstResponder {
    [_nameTextField resignFirstResponder];
    
    return YES;
}

#pragma mark - Edit group delegate

- (void)saveName {
    if ([self changedName] == NO) {
        return;
    }
    
    [groupManager setNameObjcWithGroupID:_group.groupID creator:[[MyIdentityStore sharedMyIdentityStore] identity] name:self.nameTextField.text systemMessageDate:[NSDate date] send:YES completionHandler:^(NSError * _Nullable error) {
        if (error) {
            DDLogError(@"Set group name failed: %@", error.localizedDescription);
        }
    }];
}

- (void)saveImage {
    if ([self changedImage] == NO) {
        return;
    }
    
    if (_avatarImageData) {
        [groupManager setPhotoObjcWithGroupID:_group.groupID creator:_group.groupCreatorIdentity imageData:_avatarImageData sentDate:[NSDate date] send:YES completionHandler:^(NSError * _Nullable error) {
            if (error) {
                DDLogError(@"Set group photo failed: %@", error.localizedDescription);
            }
        }];
    }
    else {
        [groupManager deletePhotoObjcWithGroupID:_group.groupID creator:_group.groupCreatorIdentity sentDate:[NSDate date] send:YES completionHandler:^(NSError * _Nullable error) {
            if (error != nil) {
                DDLogError(@"Delete group photo failed: %@", error.localizedDescription);
            }
        }];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *newValue = [textField.text stringByReplacingCharactersInRange:range withString:string];
    NSUInteger bytes = [newValue lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (bytes > 256) {
        return NO;
    }
    
    self.navigationItem.rightBarButtonItem.enabled = newValue.length > 0;
    
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    [self.navigationItem.rightBarButtonItem setEnabled:NO];

    return YES;
}

#pragma mark - Avatar delegate

- (void)avatarImageUpdated:(NSData *)newImageData {
    _avatarImageData = newImageData;
}

#pragma mark - Actions

- (IBAction)cancelAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)saveAction:(id)sender {
    [self saveName];
    [self saveImage];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
