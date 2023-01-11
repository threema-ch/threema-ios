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

#import "Old_ChatTableDataSource.h"
#import "Contact.h"
#import "ChatDefines.h"
#import "UserSettings.h"
#import "CachedCellHeight.h"
#import "ChatSectionHeaderView.h"
#import "UTIConverter.h"

#import "SystemMessage.h"
#import "TextMessage.h"
#import "ImageMessageEntity.h"
#import "LocationMessage.h"
#import "VideoMessageEntity.h"
#import "AudioMessageEntity.h"
#import "FileMessageEntity.h"
#import "LocationMessage.h"
#import "BallotMessage.h"
#import "UnreadMessageLine.h"

#import "ChatTextMessageCell.h"
#import "ChatVideoMessageCell.h"
#import "ChatLocationMessageCell.h"
#import "ChatContactCell.h"
#import "ChatAudioMessageCell.h"
#import "ChatBallotMessageCell.h"
#import "ChatFileMessageCell.h"
#import "UnreadMessageLineCell.h"
#import "ChatCallMessageCell.h"
#import "ValidationLogger.h"

#import "Threema-Swift.h"

#import <OSLog/OSLog.h>

#define SECTION_HEADER_PADDING 24.0

@interface SectionHeaderCacheElement : NSObject

@property NSInteger section;
@property CGFloat minY;
@property ChatSectionHeaderView *sectionHeaderView;

@end

@implementation SectionHeaderCacheElement
@end

@interface Old_ChatTableDataSource ()

// table sections
@property NSMutableArray *dayArray;

// rows per section
@property NSMutableArray *messagesPerDayArray;

// store section header views to show/hide later
@property NSMutableSet *sectionHeaderViewCache;

@property NSIndexPath *lastIndex;

@property NSMutableDictionary *cellHeightCache;

@property NSInteger loadedMessagesCount;

@property NSIndexPath *unreadLineIndexPath;

@property BOOL firstCellShown;

@end

@implementation Old_ChatTableDataSource

- (instancetype)init
{
    self = [super init];
    if (self) {
        _messagesPerDayArray = [NSMutableArray array];
        _dayArray = [NSMutableArray array];
        
        _cellHeightCache = [[NSMutableDictionary alloc] init];
        
        _sectionHeaderViewCache = [NSMutableSet set];
        
        _forceShowSections = NO;
        
        _loadedMessagesCount = 0;
        
        _unreadLineIndexPath = nil;
        
        _openTableView = NO;
        
        _firstCellShown = NO;
    }
    
    return self;
}

- (BOOL)hasData {
    if (_dayArray.count > 0) {
        return YES;
    }
    
    return NO;
}

- (NSIndexPath *)indexPathForLastCell {
    NSInteger sectionCount = _dayArray.count;
    if (sectionCount > 0) {
        NSArray *sectionData = [_messagesPerDayArray objectAtIndex:sectionCount - 1];
        NSInteger rowCount = [sectionData count];
        if (rowCount > 0) {
            return [NSIndexPath indexPathForRow:rowCount - 1 inSection:sectionCount - 1];
        }
    }
    
    return nil;
}

- (NSIndexPath *)indexPathForMessage:(BaseMessage *)message {
    NSInteger section = 0;
    for (NSArray *sectionData in _messagesPerDayArray) {
        NSInteger row = 0;
        for (BaseMessage *indexMessage in sectionData) {
            if ([indexMessage isKindOfClass:[BaseMessage class]] && [indexMessage.id isEqual:message.id]) {
                return [NSIndexPath indexPathForRow:row inSection:section];
            }
            
            row++;
        }
        
        section++;
    }
    
    return nil;
}

- (id)objectForIndexPath:(NSIndexPath *)indexPath {
    if (_messagesPerDayArray.count) {
        NSArray *sectionData = [_messagesPerDayArray objectAtIndex:indexPath.section];
        return [sectionData objectAtIndex:indexPath.row];
    }
    return nil;
}

- (CGFloat)getSentDateFontSize {
    float fontSize = roundf([UserSettings sharedUserSettings].chatFontSize * 13.0 / 16.0);
    if (fontSize < kSentDateMinFontSize)
        fontSize = kSentDateMinFontSize;
    else if (fontSize > kSentDateMaxFontSize)
        fontSize = kSentDateMaxFontSize;
    return fontSize;
}


// appends added sections and rows to newSections or newRows collections
- (void)addMessage:(BaseMessage *)message newSections:(NSMutableIndexSet *)newSections newRows:(NSMutableArray *)newRows visible:(BOOL)visible {
    NSDate *currentSentDate = message.date;
    NSString *dayString = [DateFormatter relativeMediumDateFor:currentSentDate];
    UIApplicationState applicationState = [[UIApplication sharedApplication] applicationState];
    BOOL showUnreadLine = YES;
    
    NSMutableArray *sectionData;
    NSInteger sectionIndex = [_dayArray indexOfObject:dayString];
    
    // fix for update from 2.8.0 to new version --> hide new messages line for the first time in a chat when first message is not read
    if (_messagesPerDayArray.count) {
        id firstMessage = _messagesPerDayArray[0][0];
        if ([firstMessage isKindOfClass:[BaseMessage class]]) {
            if (!((BaseMessage *)firstMessage).read.boolValue && !((BaseMessage *)firstMessage).isOwn.boolValue) {
                showUnreadLine = NO;
            }
        }
    }
    
    if(sectionIndex != NSNotFound) {
        sectionData = [_messagesPerDayArray objectAtIndex:sectionIndex];
        id lastObject = [sectionData lastObject];
        if (lastObject && [lastObject isKindOfClass:[BaseMessage class]]) {
            BaseMessage * temp = (BaseMessage *)lastObject;
            BOOL addSender = NO;
            
            if (temp.sender != message.sender)
                addSender = YES;
            
            if ([temp isKindOfClass:[SystemMessage class]])
                addSender = YES;
            
            /* add sender name in group conversation if necessary */
            if (addSender && message.conversation.groupId != nil && !message.isOwn.boolValue && message.sender != nil) {
                BOOL isSystemMessage = NO;
                BOOL isCallSystemMessage = NO;
                if ([message isKindOfClass:[SystemMessage class]]) {
                    isSystemMessage = YES;
                    if ([((SystemMessage *)message) isCallType]) {
                        isCallSystemMessage = YES;
                    }
                }
                if (!isSystemMessage || (isSystemMessage && isCallSystemMessage)) {
                    if (!_unreadLineIndexPath && !message.read.boolValue && showUnreadLine && (!visible || applicationState == UIApplicationStateBackground || applicationState == UIApplicationStateInactive)) {
                        [newRows addObject:[NSIndexPath indexPathForRow:sectionData.count inSection:sectionIndex]];
                        [sectionData addObject:[UnreadMessageLine new]];
                        _unreadLineIndexPath = [NSIndexPath indexPathForRow:sectionData.count-1 inSection:sectionIndex];
                    }
                    
                    [newRows addObject:[NSIndexPath indexPathForRow:sectionData.count inSection:sectionIndex]];
                    [sectionData addObject:message.sender];
                }
            }
        }
    } else {
        sectionIndex = _dayArray.count;
        sectionData = [NSMutableArray new];
        
        [newSections addIndex:sectionIndex];
        
        if (message.conversation.groupId != nil && !message.isOwn.boolValue && message.sender != nil) {
            BOOL isSystemMessage = NO;
            BOOL isCallSystemMessage = NO;
            if ([message isKindOfClass:[SystemMessage class]]) {
                isSystemMessage = YES;
                if ([((SystemMessage *)message) isCallType]) {
                    isCallSystemMessage = YES;
                }
            }
            if (!isSystemMessage || (isSystemMessage && isCallSystemMessage)) {
                if (!_unreadLineIndexPath && !message.read.boolValue && showUnreadLine && (!visible || applicationState == UIApplicationStateBackground || applicationState == UIApplicationStateInactive)) {
                    [newRows addObject:[NSIndexPath indexPathForRow:sectionData.count inSection:sectionIndex]];
                    [sectionData addObject:[UnreadMessageLine new]];
                    _unreadLineIndexPath = [NSIndexPath indexPathForRow:sectionData.count-1 inSection:sectionIndex];
                }
                
                [newRows addObject:[NSIndexPath indexPathForRow:sectionData.count inSection:sectionIndex]];
                [sectionData addObject:message.sender];
            }
        }
        
        [_dayArray addObject:dayString];
        [_messagesPerDayArray addObject:sectionData];
    }
    
    if (!_unreadLineIndexPath && !message.isOwn.boolValue && !message.read.boolValue && showUnreadLine && (!visible || applicationState == UIApplicationStateBackground || applicationState == UIApplicationStateInactive)) {
        [newRows addObject:[NSIndexPath indexPathForRow:sectionData.count inSection:sectionIndex]];
        [sectionData addObject:[UnreadMessageLine new]];
        _unreadLineIndexPath = [NSIndexPath indexPathForRow:sectionData.count-1 inSection:sectionIndex];
    }
    [newRows addObject:[NSIndexPath indexPathForRow:sectionData.count inSection:sectionIndex]];
    [sectionData addObject:message];
    
    [_chatVC observeUpdatesForMessage:message];
    
    _loadedMessagesCount++;
    _lastIndex = [newRows lastObject];
}

- (void)removeObjectFromCellHeightCache:(NSIndexPath *)indexPath {
    [_cellHeightCache removeObjectForKey:indexPath];
}

- (void)cleanCellHeightCache {
    [_cellHeightCache removeAllObjects];
}

- (void)addObjectsFrom:(Old_ChatTableDataSource *)otherDataSource {
    //note: other contains always later messages
    
    NSString *lastDay = [_dayArray lastObject];
    NSString *otherFirstDay = [otherDataSource.dayArray firstObject];
    
    if ([lastDay isEqualToString:otherFirstDay]) {
        // mix first day entries
        [_messagesPerDayArray.lastObject addObjectsFromArray:otherDataSource.messagesPerDayArray.firstObject];
        
        // append the rest
        [self array:_dayArray addArray:otherDataSource.dayArray startingAtIndex:1];
        [self array:_messagesPerDayArray addArray:otherDataSource.messagesPerDayArray startingAtIndex:1];
    } else {
        // just append everything
        [_dayArray addObjectsFromArray:otherDataSource.dayArray];
        [_messagesPerDayArray addObjectsFromArray:otherDataSource.messagesPerDayArray];
    }
    
    _loadedMessagesCount += otherDataSource.numberOfLoadedMessages;
}

- (void)array:(NSMutableArray *)array addArray:(NSMutableArray *)otherArray startingAtIndex:(NSInteger)index {
    for (NSInteger i = index; i < otherArray.count; i++) {
        id obj = [otherArray objectAtIndex:i];
        [array addObject:obj];
    }
}

- (void)refreshSectionHeadersInTableView:(UITableView *)tableView {
    for (SectionHeaderCacheElement *cacheElement in _sectionHeaderViewCache) {
        CGRect sectionRect = cacheElement.sectionHeaderView.frame;

        CGFloat alpha = 0.9;
        CGFloat delay = 0.0;
        
        NSArray *indexPaths = [tableView indexPathsForVisibleRows];
        
        if (!indexPaths || indexPaths.count == 0) {
            return;
        }
        
        NSIndexPath *firstVisibleIndexPath = [indexPaths objectAtIndex:0];
        
        if (_forceShowSections) {
            delay = 0.8;
        } else if (firstVisibleIndexPath.section == cacheElement.section && sectionRect.origin.y > cacheElement.minY && cacheElement.minY < MAXFLOAT) {
            // if y offset remains at minY the section header frame does not cover any table cells in the corresponding section
            alpha = 0.0;
            delay = 0.6;
        } else {
            // section 0 should be more persistent -> add offset
            if (cacheElement.section == 0) {
                if (_chatVC.loadEarlierMessages.hidden == NO) {
                    cacheElement.minY = sectionRect.size.height + _chatVC.loadEarlierMessages.frame.size.height;
                } else {
                    cacheElement.minY = sectionRect.size.height;
                }
            } else {
                cacheElement.minY = sectionRect.origin.y;
            }
        }
        
        if (cacheElement.sectionHeaderView.alpha == alpha) {
            continue;
        }

        UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
        [UIView animateWithDuration:0.3 delay:delay options:options animations:^{
            cacheElement.sectionHeaderView.alpha = alpha;
        } completion:^(BOOL finished) {
            ;//nop
        }];

    }
}

- (NSInteger)numberOfLoadedMessages {
    return _loadedMessagesCount;
}

- (NSIndexPath *)getUnreadLineIndexPath {
    return _unreadLineIndexPath;
}

- (BOOL)removeUnreadLine {
    // remove unread from array
    if (_messagesPerDayArray.count && _unreadLineIndexPath) {
        NSMutableArray *chatSection = [_messagesPerDayArray objectAtIndex:_unreadLineIndexPath.section];
        [chatSection removeObjectAtIndex:_unreadLineIndexPath.row];
        [_cellHeightCache removeAllObjects];
        _unreadLineIndexPath = nil;
        return YES;
    }
    return NO;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _dayArray.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *chatSection = [_messagesPerDayArray objectAtIndex:section];
    return chatSection.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSObject *object = [self objectForIndexPath:indexPath];
    
    if ([object isKindOfClass:[SystemMessage class]]) {
        if ([((SystemMessage *)object) isCallType]) {
            ChatMessageCell *cell = nil;
            static NSString *kCallMessageCell = @"CallMessageCell";
            cell = [tableView dequeueReusableCellWithIdentifier:kCallMessageCell];
            if (cell == nil) {
                cell = [[ChatCallMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCallMessageCell transparent:YES];
            }
            cell.chatVc = _chatVC;
            
            cell.message = (SystemMessage*)object;
            cell.typing = NO;
            if (indexPath == _lastIndex && _openTableView) {
                NSString *accessabilityText = [NSString stringWithFormat:@"%@%@", [BundleUtil localizedStringForKey:@"new_message_accessibility"], cell.accessibilityLabelForContent];
                UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, accessabilityText);
            }
            return cell;
        } else {
            if (((SystemMessage *)object).type.intValue == kSystemMessageContactOtherAppInfo) {
                static NSString *kSystemContactInfoMessageCell = @"SystemContactInfoMessageCell";
                ChatContactInfoSystemMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:kSystemContactInfoMessageCell];
                if (cell == nil) {
                    cell = [[ChatContactInfoSystemMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kSystemContactInfoMessageCell];
                }

                [cell setMessageWithSystemMessage:(SystemMessage*)object];

                return cell;
            } else {
                static NSString *kSystemMessageCell = @"SystemMessageCell";
                ChatSystemMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:kSystemMessageCell];
                if (cell == nil) {
                    cell = [[ChatSystemMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kSystemMessageCell];
                }
                
                [cell setMessageWithSystemMessage:(SystemMessage*)object];
                
                return cell;
            }
        }
    } else if ([object isKindOfClass:[BaseMessage class]]) {
        
        ChatMessageCell *cell = nil;
        
        if ([object isKindOfClass:[TextMessage class]]) {
            static NSString *kTextMessageCell = @"TextMessageCell";
            cell = [tableView dequeueReusableCellWithIdentifier:kTextMessageCell];
            if (cell == nil) {
                cell = [[ChatTextMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                  reuseIdentifier:kTextMessageCell transparent:YES];
            }
        } else if ([object isKindOfClass:[ImageMessageEntity class]]) {
            static NSString *kImageMessageCell = @"ImageMessageCell";
            cell = [tableView dequeueReusableCellWithIdentifier:kImageMessageCell];
            if (cell == nil) {
                cell = [[ChatImageMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:kImageMessageCell transparent:YES];
            }
        } else if ([object isKindOfClass:[VideoMessageEntity class]]) {
            static NSString *kVideoMessageCell = @"VideoMessageCell";
            cell = [tableView dequeueReusableCellWithIdentifier:kVideoMessageCell];
            if (cell == nil) {
                cell = [[ChatVideoMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:kVideoMessageCell transparent:YES];
            }
        } else if ([object isKindOfClass:[LocationMessage class]]) {
            static NSString *kLocationMessageCell = @"LocationMessageCell";
            cell = [tableView dequeueReusableCellWithIdentifier:kLocationMessageCell];
            if (cell == nil) {
                cell = [[ChatLocationMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:kLocationMessageCell transparent:YES];
            }
        } else if ([object isKindOfClass:[AudioMessageEntity class]]) {
            static NSString *kAudioMessageCell = @"AudioMessageCell";
            cell = [tableView dequeueReusableCellWithIdentifier:kAudioMessageCell];
            if (cell == nil) {
                cell = [[ChatAudioMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:kAudioMessageCell transparent:YES];
            }
        } else if ([object isKindOfClass:[BallotMessage class]]) {
            static NSString *kBallotMessageCell = @"BallotMessageCell";
            cell = [tableView dequeueReusableCellWithIdentifier:kBallotMessageCell];
            if (cell == nil) {
                cell = [[ChatBallotMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                    reuseIdentifier:kBallotMessageCell transparent:YES];
            }
        } else if ([object isKindOfClass:[FileMessageEntity class]]) {
            FileMessageEntity *fileMessageEntity = (FileMessageEntity *)object;
            if ([fileMessageEntity renderFileGifMessage] == true) {
                static NSString *kAnimGifMessageCell = @"AnimGifMessageCell";
                cell = [tableView dequeueReusableCellWithIdentifier:kAnimGifMessageCell];
                if (cell == nil) {
                    cell = [[ChatAnimatedGifMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                             reuseIdentifier:kAnimGifMessageCell transparent:YES];
                }
            }
            else if ([fileMessageEntity renderFileImageMessage] == true && fileMessageEntity.thumbnail != nil) {
                static NSString *kFileImageMessageCell = @"FileImageMessageCell";
                cell = [tableView dequeueReusableCellWithIdentifier:kFileImageMessageCell];
                if (cell == nil) {
                    cell = [[ChatFileImageMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                           reuseIdentifier:kFileImageMessageCell transparent:YES];
                }
            }
            else if ([fileMessageEntity renderFileVideoMessage] == true && fileMessageEntity.thumbnail != nil) {
                static NSString *kFileVideoMessageCell = @"FileVideoMessageCell";
                cell = [tableView dequeueReusableCellWithIdentifier:kFileVideoMessageCell];
                if (cell == nil) {
                    cell = [[ChatFileVideoMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                           reuseIdentifier:kFileVideoMessageCell transparent:YES];
                }
            }
            else if ([fileMessageEntity renderFileAudioMessage] == true) {
                static NSString *kFileAudioMessageCell = @"FileAudioMessageCell";
                cell = [tableView dequeueReusableCellWithIdentifier:kFileAudioMessageCell];
                if (cell == nil) {
                    cell = [[ChatFileAudioMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                           reuseIdentifier:kFileAudioMessageCell transparent:YES];
                }
            }
            else {
                static NSString *kFileMessageCell = @"FileMessageCell";
                cell = [tableView dequeueReusableCellWithIdentifier:kFileMessageCell];
                if (cell == nil) {
                    cell = [[ChatFileMessageCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:kFileMessageCell transparent:YES];
                }
            }
        }
        
        cell.chatVc = _chatVC;
        
        cell.message = (BaseMessage*)object;
        if (cell.message.conversation.typing.boolValue && [indexPath isEqual:_lastIndex]) {
            cell.typing = YES;
        } else {
            cell.typing = NO;
        }
        
        if (_searching) {
            [cell highlightOccurencesOf:_searchPattern];
        }
        
        if (indexPath == _lastIndex && _openTableView) {
            NSString *accessabilityText = [NSString stringWithFormat:@"%@%@", [BundleUtil localizedStringForKey:@"new_message_accessibility"], cell.accessibilityLabelForContent];
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, accessabilityText);
        }
        
        return cell;
    } else if ([object isKindOfClass:[Contact class]]) {
        static NSString *kChatContactCell = @"ChatContactCell";
        ChatContactCell *cell = [tableView dequeueReusableCellWithIdentifier:kChatContactCell];
        if (cell == nil) {
            cell = [[ChatContactCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:kChatContactCell];
        }
        cell.contact = (Contact*)object;
        [cell updateColors];
        
        return cell;
    } else if ([object isKindOfClass:[UnreadMessageLine class]]) {
        static NSString *kUnreadMessageLineCell = @"UnreadMessageLineCell";
        UnreadMessageLineCell *cell = [tableView dequeueReusableCellWithIdentifier:kUnreadMessageLineCell];
        
        if (cell == nil) {
            cell = [[UnreadMessageLineCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                reuseIdentifier:kUnreadMessageLineCell];
            cell.userInteractionEnabled = NO;
        }
        [cell updateColors];
        
        return cell;
    }
    
    return nil;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section {
    CGFloat sentDateFontSize = [self getSentDateFontSize];
    return sentDateFontSize + SECTION_HEADER_PADDING;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    CGFloat sentDateFontSize = [self getSentDateFontSize];
    CGFloat viewHeight = sentDateFontSize + SECTION_HEADER_PADDING;

    CGRect frame = CGRectMake(0.0, 0.0, tableView.frame.size.width, viewHeight);
    
    ChatSectionHeaderView *headerView = [[ChatSectionHeaderView alloc] initWithFrame:frame];
    headerView.fontSize = sentDateFontSize;
    headerView.text = [_dayArray objectAtIndex:section];
    
    __block SectionHeaderCacheElement *foundObject;
    [_sectionHeaderViewCache enumerateObjectsUsingBlock:^(SectionHeaderCacheElement *cE, BOOL * _Nonnull stop) {
        if (cE.section == section) {
            foundObject = cE;
            *stop = YES;
        }
    }];
    
    if (foundObject) {
        [_sectionHeaderViewCache removeObject:foundObject];
    }
    
    SectionHeaderCacheElement *cacheElement = [SectionHeaderCacheElement new];
    cacheElement.sectionHeaderView = headerView;
    cacheElement.section = section;
    cacheElement.minY = MAXFLOAT;
    [_sectionHeaderViewCache addObject:cacheElement];

    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat curTableWidth = tableView.safeAreaLayoutGuide.layoutFrame.size.width;

    if (_rotationOverrideTableWidth > 0) {
        curTableWidth = _rotationOverrideTableWidth;
    }
    
    CachedCellHeight *cachedHeight = [_cellHeightCache objectForKey:indexPath];
    if (cachedHeight != nil && cachedHeight.tableWidth == curTableWidth) {
        return cachedHeight.cellHeight;
    }
    
    NSObject *object = [self objectForIndexPath:indexPath];
    
    CGFloat height = 0;
    CGFloat additionalBubbleMarging = 22.0f;
    // Set SentDateCell height.
    if ([object isKindOfClass:[NSDate class]]) {
        height = [self getSentDateFontSize] + 48.0f;
    } else if ([object isKindOfClass:[TextMessage class]]) {
        height = [ChatTextMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + additionalBubbleMarging;
    } else if ([object isKindOfClass:[ImageMessageEntity class]]) {
        height = [ChatImageMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + additionalBubbleMarging;
    } else if ([object isKindOfClass:[VideoMessageEntity class]]) {
        height = [ChatVideoMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + additionalBubbleMarging;
    } else if ([object isKindOfClass:[LocationMessage class]]) {
        height = [ChatLocationMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + additionalBubbleMarging;
    } else if ([object isKindOfClass:[AudioMessageEntity class]]) {
        height = [ChatAudioMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + additionalBubbleMarging;
    } else if ([object isKindOfClass:[BallotMessage class]]) {
        height = [ChatBallotMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + additionalBubbleMarging;
    } else if ([object isKindOfClass:[FileMessageEntity class]]) {
        FileMessageEntity *fileMessageEntity = (FileMessageEntity *)object;
        
        if ([fileMessageEntity renderFileGifMessage] == true) {
            height = [ChatAnimatedGifMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + additionalBubbleMarging;
        }
        else if ([fileMessageEntity renderFileImageMessage] == true && fileMessageEntity.thumbnail != nil) {
            height = [ChatFileImageMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + additionalBubbleMarging;
        }
        else if ([fileMessageEntity renderFileVideoMessage] == true && fileMessageEntity.thumbnail != nil) {
            height = [ChatFileVideoMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + additionalBubbleMarging;
        }
        else if ([fileMessageEntity renderFileAudioMessage] == true) {
            height = [ChatFileAudioMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + additionalBubbleMarging;
        }
        else {
            height = [ChatFileMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + additionalBubbleMarging;
        }
    } else if ([object isKindOfClass:[Contact class]]) {
        height = 20;
    } else if ([object isKindOfClass:[SystemMessage class]]) {
        SystemMessage *message = (SystemMessage *)object;
        if ([message isCallType]) {
            height = [ChatCallMessageCell heightForMessage:message forTableWidth:curTableWidth] + additionalBubbleMarging;
        } else {
            if (message.type.intValue == kSystemMessageContactOtherAppInfo) {
                height = [ChatContactInfoSystemMessageCell heightFor:message forTableWidth:curTableWidth] + additionalBubbleMarging + 24.0;
            } else if (message.type.intValue == kSystemMessageVote) {
                height = [ChatContactInfoSystemMessageCell heightFor:message forTableWidth:curTableWidth] + additionalBubbleMarging + 24.0;
            } else {
                height = [ChatSystemMessageCell heightFor:message forTableWidth:curTableWidth] + additionalBubbleMarging + 5.0;
            }
        }
    } else if ([object isKindOfClass:[UnreadMessageLine class]]) {
        height = 40;
    }
    
    if (height > 0) {
        cachedHeight = [[CachedCellHeight alloc] init];
        cachedHeight.cellHeight = height;
        cachedHeight.tableWidth = curTableWidth;
        [_cellHeightCache setObject:cachedHeight forKey:indexPath];
    }
    return height;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat curTableWidth = tableView.safeAreaLayoutGuide.layoutFrame.size.width;
    if (_rotationOverrideTableWidth > 0) {
        curTableWidth = _rotationOverrideTableWidth;
    }
    
    CachedCellHeight *cachedHeight = [_cellHeightCache objectForKey:indexPath];
    if (cachedHeight != nil && cachedHeight.tableWidth == curTableWidth) {
        return cachedHeight.cellHeight;
    }
    
    NSObject *object = [self objectForIndexPath:indexPath];
    
    CGFloat height = 0;
    
    // Set SentDateCell height.
    if ([object isKindOfClass:[NSDate class]]) {
        height = [self getSentDateFontSize] + 48.0f;
    } else if ([object isKindOfClass:[TextMessage class]]) {
        height = [ChatTextMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + 17.0f;
    } else if ([object isKindOfClass:[ImageMessageEntity class]]) {
        height = [ChatImageMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + 17.0f;
    } else if ([object isKindOfClass:[VideoMessageEntity class]]) {
        height = [ChatVideoMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + 17.0f;
    } else if ([object isKindOfClass:[LocationMessage class]]) {
        height = [ChatLocationMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + 17.0f;
    } else if ([object isKindOfClass:[AudioMessageEntity class]]) {
        height = [ChatAudioMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + 17.0f;
    } else if ([object isKindOfClass:[BallotMessage class]]) {
        height = [ChatBallotMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + 17.0f;
    } else if ([object isKindOfClass:[FileMessageEntity class]]) {
        FileMessageEntity *fileMessageEntity = (FileMessageEntity *)object;
        if ([fileMessageEntity renderFileGifMessage] == true) {
            height = [ChatAnimatedGifMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + 17.0f;
        }
        else if ([fileMessageEntity renderFileImageMessage] == true && fileMessageEntity.thumbnail != nil) {
            height = [ChatFileImageMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + 17.0f;
        }
        else if ([fileMessageEntity renderFileVideoMessage] == true && fileMessageEntity.thumbnail != nil) {
            height = [ChatFileVideoMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + 17.0f;
        }
        else if ([fileMessageEntity renderFileAudioMessage] == true) {
            height = [ChatFileAudioMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + 17.0f;
        }
        else {
            height = [ChatFileMessageCell heightForMessage:(BaseMessage*)object forTableWidth:curTableWidth] + 17.0f;
        }
    } else if ([object isKindOfClass:[Contact class]]) {
        height = 20;
    } else if ([object isKindOfClass:[SystemMessage class]]) {
        SystemMessage *message = (SystemMessage *)object;
        if ([message isCallType]) {
            height = [ChatCallMessageCell heightForMessage:message forTableWidth:curTableWidth] + 17.0;
        } else {
            if (message.type.intValue == kSystemMessageContactOtherAppInfo) {
                height = [ChatContactInfoSystemMessageCell heightFor:message forTableWidth:curTableWidth] + 40.0f;
            } else {
                height = [ChatSystemMessageCell heightFor:message forTableWidth:curTableWidth] + 22.0;
            }
        }
    } else if ([object isKindOfClass:[UnreadMessageLine class]]) {
        height = 40;
    }
    
    if (height > 0) {
        cachedHeight = [[CachedCellHeight alloc] init];
        cachedHeight.cellHeight = height;
        cachedHeight.tableWidth = curTableWidth;
        [_cellHeightCache setObject:cachedHeight forKey:indexPath];
    }

    return height;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    NSObject *object = [self objectForIndexPath:indexPath];
    
    if (![object isKindOfClass:[BaseMessage class]]) {
        return NO;
    }
    
    /* don't allow image messages in sending progress to be deleted */
    if ([object isKindOfClass:[ImageMessageEntity class]]) {
        ImageMessageEntity *message = (ImageMessageEntity*)object;
        if (message.isOwn.boolValue && !message.sent.boolValue && !message.sendFailed.boolValue)
            return NO;
    }
    
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView.isEditing) {
        NSArray *selectedRows = [tableView indexPathsForSelectedRows];
        _chatVC.navigationItem.leftBarButtonItem.title = (selectedRows.count == 0) ?
        [BundleUtil localizedStringForKey:@"delete_all"] : [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"delete_n"], selectedRows.count];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView.isEditing) {
        NSArray *selectedRows = [tableView indexPathsForSelectedRows];
        NSString *deleteButtonTitle = [NSString stringWithFormat:[BundleUtil localizedStringForKey:@"delete_n"], selectedRows.count];
        
        MessageFetcher *messageFetcher = [[MessageFetcher alloc] initFor:_chatVC.conversation with:[EntityManager new]];
        if (selectedRows.count == [messageFetcher count]) {
            deleteButtonTitle = [BundleUtil localizedStringForKey:@"delete_all"];
        }
        
        _chatVC.navigationItem.leftBarButtonItem.title = deleteButtonTitle;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(nonnull UITableViewCell *)cell forRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    [Colors updateWithCell:cell setBackgroundColor: false];
    if ([cell respondsToSelector:@selector(willDisplay)]) {
        [(ChatMessageCell *)cell  willDisplay];
    }
    
    if (!_firstCellShown) {
        os_signpost_event_emit(PointsOfInterestSignpost.log, os_signpost_id_generate(PointsOfInterestSignpost.log), "willDisplayCell");
        _firstCellShown = YES;
    }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell respondsToSelector:@selector(didEndDisplaying)]) {
        [(ChatMessageCell *)cell  didEndDisplaying];
    }
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point  API_AVAILABLE(ios(13.0)){
    ChatMessageCell *messageCell = (ChatMessageCell *)[tableView cellForRowAtIndexPath:indexPath];
    return [messageCell getContextMenu:indexPath point:point];
}

- (UITargetedPreview *)tableView:(UITableView *)tableView previewForHighlightingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration  API_AVAILABLE(ios(13.0)){
    NSIndexPath *indexPath = (NSIndexPath *)configuration.identifier;
    ChatMessageCell *messageCell = (ChatMessageCell *)[tableView cellForRowAtIndexPath:indexPath];
    CGRect cellRect = [tableView rectForRowAtIndexPath:indexPath];
    UIView *superView = [tableView superview];
    CGRect convertedRect = [tableView convertRect:cellRect toView:superView];
    CGRect intersect = CGRectIntersection(tableView.frame, convertedRect);

    CGFloat height = intersect.size.height < _chatVC.chatContent.frame.size.height - 150.0 ? intersect.size.height : intersect.size.height - 150.0;

    CGRect visibleRect = CGRectMake(messageCell.frame.origin.x,  intersect.origin.y - convertedRect.origin.y, messageCell.frame.size.width, height);

    NSMutableArray *clippingRectValuesInFrameCoordinates = [NSMutableArray new];
     [clippingRectValuesInFrameCoordinates addObject:[NSValue valueWithCGRect:visibleRect]];
    UIPreviewParameters *parameters = [[UIPreviewParameters alloc] initWithTextLineRects:clippingRectValuesInFrameCoordinates];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        if (Colors.theme == ThemeDark) {
            parameters.backgroundColor = [UIColor colorWithRed:120.0/255.0 green:120.0/255.0 blue:120.0/255.0 alpha:0.9];
        } else {
            parameters.backgroundColor = [UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:0.9];;
        }
    } else {
        parameters.backgroundColor = [UIColor clearColor];
    }
        
    return [[UITargetedPreview alloc] initWithView:messageCell parameters:parameters];
}

- (UITargetedPreview *)tableView:(UITableView *)tableView previewForDismissingContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration  API_AVAILABLE(ios(13.0)){
    return [self makeTargetedPreviewForConfiguration:configuration];
}

- (UITargetedPreview *)makeTargetedPreviewForConfiguration:(UIContextMenuConfiguration *)configuration  API_AVAILABLE(ios(13.0)){
    if (configuration.identifier == nil) {
        return nil;
    }
    
    NSIndexPath *indexPath = (NSIndexPath *)configuration.identifier;
    if (indexPath == nil || self.chatVC.visible == false) {
        return nil;
    }
    
    UITableViewCell *cell = [self.chatVC.chatContent cellForRowAtIndexPath:indexPath];
    if (cell != nil && [cell isKindOfClass:[ChatMessageCell class]]) {
        ChatMessageCell *messageCell = (ChatMessageCell *)cell;
        UIPreviewParameters *parameters = [[UIPreviewParameters alloc] init];
        parameters.backgroundColor = [UIColor clearColor];
        // The creation of UITargetedPreview crashes with the error message that it cannot find a window.
        if (cell.window != nil) {
            return [[UITargetedPreview alloc] initWithView:messageCell parameters:parameters];
        }
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator  API_AVAILABLE(ios(13.0)){
    if ([animator.previewViewController isKindOfClass:[ThreemaSafariViewController class]]) {
        ThreemaSafariViewController *previewVc = (ThreemaSafariViewController *)animator.previewViewController;
        [animator addCompletion:^{
            [[UIApplication sharedApplication] openURL:previewVc.url options:@{} completionHandler:nil];
        }];
    }
    else if ([animator.previewViewController isKindOfClass:[MWPhotoBrowser class]]) {
        NSIndexPath *indexPath = (NSIndexPath *)configuration.identifier;
        ChatImageMessageCell *imageMessageCell = (ChatImageMessageCell *)[tableView cellForRowAtIndexPath:indexPath];
        [animator addCompletion:^{
            [self.chatVC imageMessageTapped:(ImageMessageEntity*)imageMessageCell.message];
        }];
    }
}


#pragma mark - scroll view delegate

// forward to chat view (table view delegate & scroll view delegate: there can only be one)

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    _forceShowSections = NO;
    [self refreshSectionHeadersInTableView:_chatVC.chatContent];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [_chatVC scrollViewDidScroll:scrollView];
    
    [self refreshSectionHeadersInTableView:_chatVC.chatContent];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [_chatVC scrollViewWillBeginDragging:scrollView];

    _forceShowSections = YES;
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    [_chatVC scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
    if (fabs(velocity.y) < 0.2) {
        _forceShowSections = NO;
        [self refreshSectionHeadersInTableView:_chatVC.chatContent];
    }
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    return [_chatVC scrollViewShouldScrollToTop:scrollView];
}

@end
