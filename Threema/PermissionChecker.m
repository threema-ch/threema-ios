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

#import "PermissionChecker.h"
#import "UserSettings.h"
#import "MyIdentityStore.h"
#import "Contact.h"
#import "Group.h"
#import "EntityManager.h"

@interface PermissionChecker ()

@property UIViewController *viewController;

@end

@implementation PermissionChecker

+ (instancetype)permissionChecker {
    PermissionChecker *permissionChecker = [[PermissionChecker alloc] init];
    
    return permissionChecker;
}

+ (instancetype)permissionCheckerPresentingAlarmsOn:(UIViewController *)viewController {
    PermissionChecker *permissionChecker = [PermissionChecker permissionChecker];
    permissionChecker.viewController = viewController;
    
    return permissionChecker;
}

- (BOOL)canSendIn:(Conversation *)conversation entityManager:(EntityManager *)entityManager {
    EntityManager *manager = entityManager;
    
    if (manager == nil) {
        manager = [[EntityManager alloc] init];
    }
    // Check for blacklisted contact
    if (conversation.groupId == nil && [[UserSettings sharedUserSettings].blacklist containsObject:conversation.contact.identity]) {
        if (_viewController) {
            [self showAlert:NSLocalizedString(@"contact_blocked_cannot_send", nil)];
        }
        
        return NO;
    }
    
    // Check for empty groups
    if (conversation.groupId != nil && conversation.members.count == 0) {
        if (_viewController) {
            [self showAlert:NSLocalizedString(@"no_more_members", nil)];
        }
        
        return NO;
    }
    
    // Check that the group was started while we were using the same identity as now
    if (conversation.groupMyIdentity != nil && ![conversation.groupMyIdentity isEqualToString:[MyIdentityStore sharedMyIdentityStore].identity]) {
        if (_viewController) {
            [self showAlert:NSLocalizedString(@"group_different_identity", nil)];
        }
        
        return NO;
    }
    
    // Check for invalid contact
    if (conversation.groupId == nil && conversation.contact.state.intValue == kStateInvalid) {
        if (_viewController) {
            [self showAlert:NSLocalizedString(@"contact_invalid_cannot_send", nil)];
        }
        
        return NO;
    }
    
    // Check group state
    if (conversation.isGroup) {
        Group *group = [manager.entityFetcher groupForConversation:conversation];
        if (group.didLeave || group.didForcedLeave) {
            if (_viewController) {
                [self showAlert:NSLocalizedString(@"group_is_not_member", nil)];
            }
            
            return NO;
        }
    }
    
    return YES;
}

- (void)showAlert:(NSString *)title {
    [UIAlertTemplate showAlertWithOwner:_viewController title:title message:@"" actionOk:nil];
}

@end
