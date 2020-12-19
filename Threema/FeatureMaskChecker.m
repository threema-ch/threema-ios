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

#import "FeatureMaskChecker.h"
#import "FeatureMask.h"
#import "BundleUtil.h"
#import "Utils.h"
#import "ProtocolDefines.h"
#import "Conversation.h"
#import "AppDelegate.h"

typedef void (^CompletionBlock)(void);

static FeatureMaskChecker *strongReference;

@interface FeatureMaskChecker ()

@property BOOL hasValidContacts;
@property (copy) CompletionBlock onSuccess;
@property (copy) CompletionBlock onFailure;

@end

@implementation FeatureMaskChecker

- (void)checkFileTransferFor:(NSSet *)conversations presentAlarmOn:(UIViewController *)viewController onSuccess:(void (^)(void))onSuccess onFailure:(void (^)(void))onFailure{
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    
    [FeatureMask checkFeatureMask:FEATURE_MASK_FILE_TRANSFER forConversations:conversations onCompletion:^(NSArray *unsupportedContacts) {
        if ([unsupportedContacts count] > 0) {
            NSMutableSet *allContacts = [NSMutableSet set];
            for (Conversation *conversation in conversations) {
                [allContacts addObjectsFromArray:conversation.participants.allObjects];
            }
            
            NSString *messageFormat;
            if ([unsupportedContacts count] == [allContacts count]) {
                _hasValidContacts = NO;
                messageFormat = [BundleUtil localizedStringForKey:@"error_message_none_feature_level"];
            } else {
                _hasValidContacts = YES;
                messageFormat = [BundleUtil localizedStringForKey:@"error_message_feature_level"];
            }
            
            NSString *participantNames = [Utils stringFromContacts:unsupportedContacts];
            NSString *message = [NSString stringWithFormat:messageFormat, participantNames];
            
            NSString *title = [BundleUtil localizedStringForKey:@"error_title_feature_level"];
            
            [UIAlertTemplate showAlertWithOwner:[[AppDelegate sharedAppDelegate] currentTopViewController] title:title message:message actionOk:^(UIAlertAction * _Nonnull okAction) {
                if (_hasValidContacts) {
                    _onSuccess();
                } else {
                    _onFailure();
                }
            }];
        } else {
            _onSuccess();
        }
    }];
}

@end
