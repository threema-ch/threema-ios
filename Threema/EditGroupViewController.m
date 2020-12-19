//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2020 Threema GmbH
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

#import "EditGroupViewController.h"
#import "AvatarMaker.h"
#import "AppDelegate.h"
#import "ModalPresenter.h"
#import "UIDefines.h"
#import "UIImage+Resize.h"
#import "EntityManager.h"
#import "MessageSender.h"
#import "EntityManager.h"
#import "GroupPhotoSender.h"
#import "CreateGroupNavigationController.h"

@interface EditGroupViewController () <EditableAvatarViewDelegate, UITextFieldDelegate>

@property NSString *groupName;
@property NSData *avatarImageData;

@end

@implementation EditGroupViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _avatarView.presentingViewController = self;
    _avatarView.delegate = self;
    _avatarView.canDeleteImage = YES;
    _avatarView.canChooseImage = YES;

    _nameTextField.delegate = self;
    _nameTextField.placeholder = NSLocalizedString(@"group name", nil);
    
    [Colors updateKeyboardAppearanceFor:self.nameTextField];
    
    if ([self.navigationController isKindOfClass:[CreateGroupNavigationController class]]) {
        NSData *cloneGroupId = ((CreateGroupNavigationController *)self.navigationController).cloneGroupId;
        if (cloneGroupId) {
            EntityManager *entityManager = [[EntityManager alloc] init];
            Conversation *conversation = [entityManager.entityFetcher conversationForGroupId:cloneGroupId];
            
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

- (void)setGroup:(GroupProxy *)group {
    _group = group;
    
    _groupName = _group.conversation.groupName;
    
    if (_group.conversation.groupImage) {
        _avatarImageData = _group.conversation.groupImage.data;
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
    if ([_nameTextField.text isEqualToString:_group.conversation.groupName]) {
        return NO;
    }
    
    return YES;
}

- (BOOL)changedImage {
    if (_group.conversation.groupImage.data == _avatarImageData) {
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
        self.title = NSLocalizedString(@"edit group", nil);
     
        _nameTextField.text = _groupName;
        
        if (_group.conversation.groupImage) {
            _avatarView.imageData = _avatarImageData;
        }
    } else {
        self.title = NSLocalizedString(@"new group", nil);
        
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
    
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        _group.conversation.groupName = self.nameTextField.text;
    }];
    
    [MessageSender sendGroupRenameMessageForConversation:_group.conversation addSystemMessage:YES];
}

- (void)saveImage {
    if ([self changedImage] == NO) {
        return;
    }
    
    GroupPhotoSender *sender = [[GroupPhotoSender alloc] init];
    
    Conversation *groupConversation = _group.conversation;
    [sender startWithImageData:_avatarImageData inConversation:groupConversation toMember:nil onCompletion:^{
        EntityManager *entityManager = [[EntityManager alloc] init];
        [entityManager performSyncBlockAndSafe:^{
            
            // Delete old image
            if (groupConversation.groupImage != nil) {
                [[entityManager entityDestroyer] deleteObjectWithObject:groupConversation.groupImage];
                groupConversation.groupImage = nil;
            }
            
            // Save new image if there is any
            if (_avatarImageData != nil) {
                ImageData *dbImage = [entityManager.entityCreator imageData];
                dbImage.data = _avatarImageData;
            
                groupConversation.groupImage = dbImage;
            }
        }];
    } onError:^(NSError *error) {
        [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSUInteger bytes = [textField.text lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (bytes > 256 && ![string isEqualToString:@""]) {
        return NO;
    }
    
    NSString *newValue = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if (newValue.length > 0) {
        [self.navigationItem.rightBarButtonItem setEnabled:YES];
    } else {
        [self.navigationItem.rightBarButtonItem setEnabled:NO];
    }
    
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
