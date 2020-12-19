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

#import "CreateGroupNavigationController.h"
#import "PickGroupMembersViewController.h"
#import "EditGroupViewController.h"
#import "EntityManager.h"
#import "NaClCrypto.h"
#import "MyIdentityStore.h"
#import "MessageSender.h"
#import "GroupPhotoSender.h"
#import "ModalPresenter.h"
#import "UserSettings.h"

@interface CreateGroupNavigationController () <EditGroupDelegate>

@property NSData *groupImageData;
@property NSString *groupName;
@property NSSet *groupMembers;

@end

@implementation CreateGroupNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.dismissOnTapOutside = NO;
    
    if ([self.topViewController isKindOfClass:[EditGroupViewController class]]) {
        EditGroupViewController *editGroupController = (EditGroupViewController *)self.topViewController;
        editGroupController.delegate = self;
        
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"cancel", nil) style:UIBarButtonItemStylePlain target:self action:@selector(cancelAction:)];
        editGroupController.navigationItem.leftBarButtonItem = cancelButton;
        
        UIBarButtonItem *nextButton;
        if (_cloneGroupId) {
            nextButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"save", nil) style:UIBarButtonItemStyleDone target:self action:@selector(saveAction:)];
        } else {
            nextButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"next", nil) style:UIBarButtonItemStyleDone target:self action:@selector(nextAction:)];
        }
        editGroupController.navigationItem.rightBarButtonItem = nextButton;
    }
}

- (void)createNewGroup {
    __block Conversation *conversation;
    EntityManager *entityManager = [[EntityManager alloc] init];
    [entityManager performSyncBlockAndSafe:^{
        conversation = [entityManager.entityCreator conversation];
        conversation.groupId = [[NaClCrypto sharedCrypto] randomBytes:kGroupIdLen];
        conversation.groupMyIdentity = [MyIdentityStore sharedMyIdentityStore].identity;
        conversation.groupName = _groupName;
        [conversation addMembers:_groupMembers];
        
        if (_groupImageData) {
            ImageData *dbImage = [entityManager.entityCreator imageData];
            dbImage.data = _groupImageData;
            conversation.groupImage = dbImage;
        }

    }];
    
    /* send group create messages to all members */
    if ([conversation isGroup]) {
        GroupProxy *group = [GroupProxy groupProxyForConversation:conversation];
        [group syncGroupInfoToAll];
    }
    
    if (_groupName) {
        [MessageSender sendGroupRenameMessageForConversation:conversation addSystemMessage:YES];
    }
    
    if (_groupImageData) {
        [self sendGroupPhotoMessageForConversation:conversation];
    }
    
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          conversation, kKeyConversation,
                          [NSNumber numberWithBool:YES], kKeyForceCompose,
                          nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil
                                                      userInfo:info];
}

- (void)sendGroupPhotoMessageForConversation:(Conversation *)conversation {
    GroupPhotoSender *sender = [[GroupPhotoSender alloc] init];
    
    [sender startWithImageData:_groupImageData inConversation:conversation toMember:nil onCompletion:^{
        ;//nop
    } onError:^(NSError *error) {
        [UIAlertTemplate showAlertWithOwner:self title:error.localizedDescription message:error.localizedFailureReason actionOk:nil];
    }];
}

#pragma mark - Navigation controller

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ([viewController isKindOfClass:[PickGroupMembersViewController class]]) {
        PickGroupMembersViewController *pickMembersController = (PickGroupMembersViewController *)viewController;
        pickMembersController.delegate = self;
        [pickMembersController setMembers:_groupMembers];
        
        UIBarButtonItem *createButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"create", nil) style:UIBarButtonItemStyleDone target:self action:@selector(saveAction:)];
        pickMembersController.navigationItem.rightBarButtonItem = createButton;

        pickMembersController.navigationItem.leftBarButtonItem = nil;
    }

    [super pushViewController:viewController animated:animated];
}

#pragma mark - actions

- (void)cancelAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)nextAction:(id)sender {
    @try {
        [self.topViewController performSegueWithIdentifier:@"nextSegue" sender:self];
    }
    @catch (NSException *exception) {
        ;//ignore
    }
}

- (void)saveAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        if (_cloneGroupId) {
            // add members except me
            EntityManager *entityManager = [[EntityManager alloc] init];
            Conversation *conversation = [entityManager.entityFetcher conversationForGroupId:_cloneGroupId];
            
            Contact *me = [entityManager.entityFetcher contactForId:[MyIdentityStore sharedMyIdentityStore].identity];
            if (me != nil && [conversation.members containsObject:me]) {
                NSMutableSet *cloneGroupMembers = [[NSMutableSet alloc] init];
                for (Contact *member in conversation.members) {
                    if ([member isEqual:me] == NO) {
                        [cloneGroupMembers addObject:member];
                    }
                }
                
                _groupMembers = cloneGroupMembers;
            } else {
                _groupMembers = conversation.members;
            }
        }
        [self createNewGroup];
    }];

}

#pragma mark - Edit group delegate

- (void)group:(GroupProxy *)group updatedName:(NSString *)newName {
    _groupName = newName;
}

- (void)group:(GroupProxy *)group updatedImage:(NSData *)newImageData {
    _groupImageData = newImageData;
}

- (void)group:(GroupProxy *)group updatedMembers:(NSSet *)newMembers {
    _groupMembers = newMembers;
}

@end
