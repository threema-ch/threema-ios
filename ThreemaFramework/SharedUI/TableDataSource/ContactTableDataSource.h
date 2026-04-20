#import <Foundation/Foundation.h>
#import "ContactGroupDataSource.h"
#import <CoreData/CoreData.h>

@class ContactEntity;

@interface ContactTableDataSource : NSObject <ContactGroupDataSource>

+ (instancetype)contactTableDataSource;
+ (instancetype)contactTableDataSourceWithMembers:(NSMutableSet *)members;
+ (instancetype)contactTableDataSourceWithFetchedResultsControllerDelegate:(id<NSFetchedResultsControllerDelegate>)delegate members:(NSMutableSet *)members;

@property (nonatomic) BOOL excludeGatewayContacts;
@property (nonatomic) BOOL excludeEchoEcho;

- (ContactEntity *)contactAtIndexPath:(NSIndexPath *)indexPath;

- (NSIndexPath *)indexPathForObject:(id)object;

- (NSSet *)getSelectedContacts;

- (void)updateSelectedContacts:(NSSet *)contacts;

- (void)refreshContactSortIndices;

- (NSUInteger)countOfContacts;

@end
