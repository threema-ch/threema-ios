#ifndef Threema_ContactGroupDataSource_h
#define Threema_ContactGroupDataSource_h

@protocol ContactGroupDataSource <UITableViewDataSource>

- (NSSet *)selectedConversations;

- (BOOL)canSelectCellAtIndexPath:(NSIndexPath *)indexPath;

- (void)selectedCellAtIndexPath:(NSIndexPath *)indexPath selected:(BOOL)selected;

- (void)filterByWords:(NSArray *)words;

@optional
- (void)setIgnoreFRCUpdates:(BOOL)ignoreUpdates;

- (BOOL)isFiltered;

@end

#endif
