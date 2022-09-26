//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2022 Threema GmbH
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

#import "ChatContactCell.h"
#import "UserSettings.h"
#import "Contact.h"
#import "ChatDefines.h"
#import "Threema-Swift.h"

#define CONTACT_LABEL_BG_COLOR [Colors.backgroundView colorWithAlphaComponent:0.9]

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelAll;
#else
static const DDLogLevel ddLogLevel = DDLogLevelNotice;
#endif


@implementation ChatContactCell {
    UILabel *nameLabel;
}

@synthesize contact;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {        
        self.backgroundColor = [UIColor clearColor];
        
        if ([UserSettings sharedUserSettings].wallpaper) {
            nameLabel = [[RoundedRectLabel alloc] init];
            nameLabel.backgroundColor = CONTACT_LABEL_BG_COLOR;
            ((RoundedRectLabel*)nameLabel).cornerRadius = 6;
        } else {
            nameLabel = [[UILabel alloc] init];
            nameLabel.backgroundColor = [UIColor clearColor];
        }
        
        float fontSize = roundf([UserSettings sharedUserSettings].chatFontSize * 12.0 / 16.0);
        if (fontSize < kChatContactMinFontSize)
            fontSize = kChatContactMinFontSize;
        else if (fontSize > kChatContactMaxFontSize)
            fontSize = kChatContactMaxFontSize;
        nameLabel.font = [UIFont systemFontOfSize:fontSize];
        nameLabel.numberOfLines = 1;
        nameLabel.frame = CGRectMake(56, 4, self.contentView.frame.size.width - 32, 16);
        nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        nameLabel.textAlignment = NSTextAlignmentLeft;
        [self.contentView addSubview:nameLabel];
        
        [self updateColors];
    }
    
    return self;
}

- (void)dealloc {
    [contact removeObserver:self forKeyPath:@"displayName"];
}

- (void)updateName {
    /* append public nickname (if no real name is available) */
    if ([contact.displayName isEqualToString:contact.identity] && contact.publicNickname.length > 0) {
        nameLabel.text = [NSString stringWithFormat:@"%@ (~%@)", contact.identity, contact.publicNickname];
    } else {
        nameLabel.text = contact.displayName;
    }
}

- (void)willDisplay {
    [self updateColors];
}

- (void)updateColors {
    nameLabel.textColor = Colors.textLight;
}

- (void)setContact:(Contact *)newContact {
    [contact removeObserver:self forKeyPath:@"displayName"];
    contact = newContact;
    [contact addObserver:self forKeyPath:@"displayName" options:0 context:nil];
    
    [self updateName];
    
    /* set background again as it seems to be lost sometimes with RoundedRectLabel */
    if ([UserSettings sharedUserSettings].wallpaper)
        nameLabel.backgroundColor = CONTACT_LABEL_BG_COLOR;
    else
        nameLabel.backgroundColor = [UIColor clearColor];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([object isKindOfClass:[Contact class]]) {
        @try {
            Contact *contactObject = (Contact *)object;
            if (contactObject.objectID == contact.objectID) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateName];
                });
            }
        } @catch (NSException *exception) {
            DDLogError(@"[Observer] Can't cast object into contact");
        }
    }
}

- (UIContextMenuConfiguration *)getContextMenu:(NSIndexPath *)indexPath point:(CGPoint)point API_AVAILABLE(ios(13.0)) {
    return nil;
}

@end
