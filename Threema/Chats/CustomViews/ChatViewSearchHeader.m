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

#import "ChatViewSearchHeader.h"
#import "EntityFetcher.h"
#import "BundleUtil.h"
#import "ChatMessageCell.h"
#import <MBProgressHUD/MBProgressHUD.h>

@interface ChatViewSearchHeader () <UISearchBarDelegate>

@property EntityManager *entityManager;
@property NSString *searchPattern;
@property NSArray *messageHits;
@property NSInteger currentIndex;

@property ChatMessageCell *currentCell;

@property BOOL shouldCancel;

@end

@implementation ChatViewSearchHeader

- (void)awakeFromNib {
    self.searchBar.delegate = self;
    self.entityManager = [[EntityManager alloc] init];
    
    [self setup];

    [super awakeFromNib];
}

- (void)setup {
    _label.hidden = YES;
    
    [_cancelButton setTitle:[BundleUtil localizedStringForKey:@"cancel"] forState:UIControlStateNormal];
    [_prevButton setTitle:[BundleUtil localizedStringForKey:@"previous"] forState:UIControlStateNormal];
    [_nextButton setTitle:[BundleUtil localizedStringForKey:@"next"] forState:UIControlStateNormal];
    
    _searchBar.barStyle = UIBarStyleBlackTranslucent;
    
    [self updateColors];
    
    [self updateButtons];
}

- (BOOL)becomeFirstResponder {
    return [_searchBar becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
    return [_searchBar resignFirstResponder];
}

- (void)searchPattern:(NSString *)pattern {
    // cancel previous
    _shouldCancel = YES;
 
    [_currentCell setBubbleHighlighted:NO];

    _searchPattern = pattern;
    
    _messageHits = [_entityManager.entityFetcher messagesContaining:pattern inConversation:_chatViewController.conversation];

    [self updateChatViewController];
    
    if ([_messageHits count] > 0) {
        _currentIndex = 0;
        [self  stepSearchResults];
    }
    

    [self updateLabel];
    [self updateButtons];
}

- (void)updateChatViewController {
    if ([_messageHits count] > 0) {
        _chatViewController.searchPattern = _searchPattern;
    } else {
        _chatViewController.searchPattern = nil;
    }
    
    [self updateVisibleCells];
}

- (void)cancelSearch {
    _shouldCancel = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)addLoadEarlierMessagesHUD {
    if ([MBProgressHUD HUDForView:_chatViewController.view] != nil) {
        return;
    }
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:_chatViewController.view animated:YES];
    hud.label.text = [BundleUtil localizedStringForKey:@"load_earlier_messages"];
    [hud.button setTitle:[BundleUtil localizedStringForKey:@"cancel"] forState:UIControlStateNormal];
    [hud.button addTarget:self action:@selector(cancelSearch) forControlEvents:UIControlEventTouchUpInside];
}

- (void)inChatGoToMessage:(BaseMessage *)message {
    
    _shouldCancel = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        __block NSIndexPath *indexPath = nil;
        
        while (_shouldCancel == NO) {
            indexPath = [_chatViewController indexPathForMessage:message];
            
            if (indexPath) {
                // found message
                break;
            } else {
                NSInteger offset = [_chatViewController messageOffset];
                
                if (offset > 0) {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [self addLoadEarlierMessagesHUD];
                        
                        [_chatViewController loadEarlierMessagesAction:nil];

                        if (_shouldCancel) {
                            return;
                        }
                        
                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
                        [_chatViewController.chatContent scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
                    });
                } else {
                    break;
                }
            }
        }
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:_chatViewController.view animated:YES];
        });
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (indexPath) {
                // safety check if indexPath is still valid
                if ([self isValidIndexPath:indexPath] == NO) {
                    return;
                }
                
                //deselect previous cell
                [_currentCell setBubbleHighlighted:NO];

                UITableViewScrollPosition scrollPosition;
                if (_searchBar.isFirstResponder) {
                    scrollPosition = UITableViewScrollPositionBottom;
                } else {
                    scrollPosition = UITableViewScrollPositionMiddle;
                }
                
                [_chatViewController.chatContent scrollToRowAtIndexPath:indexPath atScrollPosition:scrollPosition animated:YES];
                
                _currentCell = (ChatMessageCell *)[_chatViewController.chatContent cellForRowAtIndexPath:indexPath];

                CGFloat delayMs;
                if (_currentCell) {
                    delayMs = 100.0;
                } else {
                    // cell not visible yet
                    delayMs = 400.0;
                }

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayMs * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    _currentCell = (ChatMessageCell *)[_chatViewController.chatContent cellForRowAtIndexPath:indexPath];
                    [_currentCell setBubbleHighlighted:YES];
                    
                    if (UIAccessibilityIsVoiceOverRunning()) {
                        NSString *text = _currentCell.accessibilityLabel;
                        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text);
                    }
                });
            }
        });
    });
}

- (BOOL)isValidIndexPath:(NSIndexPath *)indexPath {
    NSInteger sectionCount = [_chatViewController.chatContent.dataSource numberOfSectionsInTableView:_chatViewController.chatContent];
    if (indexPath.section >= sectionCount) {
        return NO;
    }
    
    NSInteger rowCount = [_chatViewController.chatContent.dataSource tableView:_chatViewController.chatContent numberOfRowsInSection:indexPath.section];
    if (indexPath.row >= rowCount) {
        return NO;
    }
    
    return YES;
}

- (void)updateVisibleCells {
    NSArray *visibleCells = [_chatViewController.chatContent visibleCells];
    for (ChatMessageCell *cell in visibleCells) {
        if ([cell isKindOfClass:[ChatMessageCell class]]) {
            if ([_messageHits containsObject:cell.message]) {
                [cell highlightOccurencesOf:_searchPattern];
            } else {
                [cell highlightOccurencesOf:nil];
            }
            
            [cell setNeedsLayout];
        }
    }
}

- (void)selectMessageAt:(NSInteger)index {
    BaseMessage *message = [_messageHits objectAtIndex:index];
    [self inChatGoToMessage:message];
    
    [self updateLabel];
}

- (void)updateLabel {
    if ([_messageHits count] > 0) {
        NSString *format = [BundleUtil localizedStringForKey:@"chat_search_label_format"];
        _label.text = [NSString stringWithFormat:format, _currentIndex + 1, [_messageHits count]];
        _label.hidden = NO;
    } else {
        _label.hidden = YES;
    }
}

- (void)updateButtons {
    if ([_messageHits count] > 1) {
        _prevButton.enabled = YES;
        _nextButton.enabled = YES;
    } else {
        _prevButton.enabled = NO;
        _nextButton.enabled = NO;
    }
}

- (void)updateColors {
    [Colors updateWithSearchBar:self.searchBar];
    
    _label.textColor = Colors.text;
    
    _hairlineView1.backgroundColor = Colors.hairLine;
    _hairlineView2.backgroundColor = Colors.hairLine;
}


#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(searchPattern:) withObject:searchText afterDelay:0.75];
}


- (IBAction)cancelAction:(id)sender {
    _shouldCancel = YES;
    _messageHits = nil;
    _searchPattern = nil;
    
    [_currentCell setBubbleHighlighted:NO];
    [self updateChatViewController];
    
    [self resignFirstResponder];
    [_delegate didCancelSearch];
}

- (void)stepSearchResults {
    NSInteger count = [_messageHits count];
    
    [self selectMessageAt:_currentIndex];
    
    _prevButton.enabled = (_currentIndex < count - 1);
    
    _nextButton.enabled = (_currentIndex > 0);
}

// note: order in _messageHits is descending
- (IBAction)prevAction:(id)sender {
    if (_currentIndex < [_messageHits count] - 1) {
        _currentIndex++;
    }
    
    [self resignFirstResponder];
    [self stepSearchResults];
}

- (IBAction)nextAction:(id)sender {
    if (_currentIndex > 0) {
        _currentIndex--;
    }
    
    [self resignFirstResponder];
    [self stepSearchResults];
}

@end
