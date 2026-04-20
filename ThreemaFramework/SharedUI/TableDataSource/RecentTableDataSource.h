#import <Foundation/Foundation.h>
#import "ContactGroupDataSource.h"


@class ConversationEntity;

@interface RecentTableDataSource : NSObject  <ContactGroupDataSource>

+ (instancetype)recentTableDataSource;

- (void)insertSelectedConversation:(ConversationEntity *) conversation;

@end
