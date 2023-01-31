//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

#import <Foundation/Foundation.h>

@protocol ChatViewControllerActionsProtocol <NSObject>

@property UITableView *chatContent;
@property Conversation *conversation;
@property UINavigationController *navigationController;
@property UIView *view;
@property Old_ChatBar *chatBar;
@property UIViewController *presentedViewController;
@property UIStoryboard *storyboard;

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated: (BOOL)flag completion:(void (^)(void))completion;
- (void)dismissViewControllerAnimated: (BOOL)flag completion: (void (^)(void))completion;

- (void)updateConversation;
- (void)updateConversationLastMessage;
- (id)objectAtIndexPath:(NSIndexPath *)indexPath;
- (void)doResignFirstResponder;


@property(nonatomic,getter=isEditing) BOOL editing;
- (void)setEditing:(BOOL)editing animated:(BOOL)animated;

@end
