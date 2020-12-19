//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2016-2020 Threema GmbH
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

@protocol SenderItemDelegate <NSObject>

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;

- (void)setProgress:(NSNumber *)progress forItem:(id)item;

- (void)finishedItem:(id)item;

- (void)setFinished;

@end

@interface SenderItemManager : NSObject

@property id<SenderItemDelegate> delegate;

@property (readonly) BOOL containsFileItem;

@property BOOL sendAsFile;

@property BOOL shouldCancel;

- (void)addItem:(NSItemProvider *)itemProvider forType:(NSString *)type secondType:(NSString *)secondType;

- (void)addText:(NSString *)text;

- (NSUInteger)itemCount;

- (void)sendItemsTo:(NSSet *)conversations;

@end
