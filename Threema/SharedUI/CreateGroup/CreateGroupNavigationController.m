//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2015-2023 Threema GmbH
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
#import "Threema-Swift.h"

#import "CreateGroupNavigationController.h"
#import "PickGroupMembersViewController.h"
#import "Old_EditGroupViewController.h"
#import "NaClCrypto.h"
#import "MyIdentityStore.h"
#import "MessageSender.h"
#import "GroupPhotoSender.h"
#import "ModalPresenter.h"
#import "UserSettings.h"
#import "ContactStore.h"
#import "Contact.h"
#import <PromiseKit/PromiseKit.h>
#import "BundleUtil.h"
#import "AppGroup.h"
#import "ContactsNavigationController.h"
#import "AppDelegate.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif

@interface CreateGroupNavigationController () <EditGroupDelegate>

@property NSData *groupImageData;
@property NSString *groupName;
@property NSSet *groupMembers;

@end

@implementation CreateGroupNavigationController {
    GroupManager *groupManager;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        self->groupManager = [[GroupManager alloc] init];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.dismissOnTapOutside = NO;
    
    if ([self.topViewController isKindOfClass:[Old_EditGroupViewController class]]) {
        Old_EditGroupViewController *editGroupController = (Old_EditGroupViewController *)self.topViewController;
        editGroupController.delegate = self;
        
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:[BundleUtil localizedStringForKey:@"cancel"] style:UIBarButtonItemStylePlain target:self action:@selector(cancelAction:)];
        editGroupController.navigationItem.leftBarButtonItem = cancelButton;
        
        UIBarButtonItem *nextButton;
        if (_cloneGroupId) {
            nextButton = [[UIBarButtonItem alloc] initWithTitle:[BundleUtil localizedStringForKey:@"save"] style:UIBarButtonItemStyleDone target:self action:@selector(saveAction:)];
        } else {
            nextButton = [[UIBarButtonItem alloc] initWithTitle:[BundleUtil localizedStringForKey:@"next"] style:UIBarButtonItemStyleDone target:self action:@selector(nextAction:)];
        }
        editGroupController.navigationItem.rightBarButtonItem = nextButton;
    }
}

- (void)createNewGroup {
    NSData *groupId = [[NaClCrypto sharedCrypto] randomBytes:kGroupIdLen];
    NSString *groupCreator = [MyIdentityStore sharedMyIdentityStore].identity;
    
    NSMutableSet *groupMemberIdentities = [[NSMutableSet alloc] init];
    for (Contact *contact in _groupMembers) {
        [groupMemberIdentities  addObject:contact.identity];
    }
    
    [groupManager createOrUpdateObjcWithGroupID:groupId creator:groupCreator members:groupMemberIdentities systemMessageDate:[NSDate date] completionHandler:^(Group * _Nullable grp, __unused NSSet<NSString *> * _Nullable newMembers) {

        if (grp != nil) {
            if (_groupName) {
                [groupManager setNameObjcWithGroup:grp name:_groupName systemMessageDate:[NSDate date] send:YES]
                    .catch(^(NSError *error){
                        DDLogError(@"Set group name failed: %@", [error localizedDescription]);
                    });
            }

            if (_groupImageData) {
                [groupManager setPhotoObjcWithGroupID:groupId creator:groupCreator imageData:_groupImageData sentDate:[NSDate date] send:YES]
                .catch(^(NSError *error){
                    DDLogError(@"Set group photo failed: %@", [error localizedDescription]);
                });
            }
            
            UITabBarController *mainTabBar = [AppDelegate getMainTabBarController];
            if ([[mainTabBar selectedViewController] isKindOfClass:[ContactsNavigationController class]]) {
                NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                                      grp, kKeyGroup,
                                      nil
                                      ];
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowGroup object:nil
                                                                  userInfo:info];
            } else {
                NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                                      grp.conversation, kKeyConversation,
                                      [NSNumber numberWithBool:YES], kKeyForceCompose,
                                      nil
                                      ];
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationShowConversation object:nil
                                                                  userInfo:info];
            }
        }
    } errorHandler:^(NSError * _Nullable error) {
        DDLogError(@"Error while createing group: %@", [error localizedDescription]);
    }];
}

#pragma mark - Navigation controller

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ([viewController isKindOfClass:[PickGroupMembersViewController class]]) {
        PickGroupMembersViewController *pickMembersController = (PickGroupMembersViewController *)viewController;
        pickMembersController.delegate = self;
        [pickMembersController setMembers:_groupMembers];
        
        UIBarButtonItem *createButton = [[UIBarButtonItem alloc] initWithTitle:[BundleUtil localizedStringForKey:@"create"] style:UIBarButtonItemStyleDone target:self action:@selector(saveAction:)];
        pickMembersController.navigationItem.rightBarButtonItem = createButton;

        pickMembersController.navigationItem.leftBarButtonItem = nil;
    }

    [super pushViewController:viewController animated:animated];
    
    [UserReminder maybeShowNoteGroupReminderOn:viewController];
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
            _groupMembers = [groupManager getGroupMembersForClone:_cloneGroupId creator:_cloneGroupCreator];
        }
        [self createNewGroup];
    }];
}

#pragma mark - Edit group delegate

- (void)group:(Group *)group updatedName:(NSString *)newName {
    _groupName = newName;
}

- (void)group:(Group *)group updatedImage:(NSData *)newImageData {
    _groupImageData = newImageData;
}

- (void)group:(Group *)group updatedMembers:(NSSet *)newMembers {
    _groupMembers = newMembers;
}

@end
