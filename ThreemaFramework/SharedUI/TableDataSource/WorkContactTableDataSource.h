#import <Foundation/Foundation.h>
#import "ContactGroupDataSource.h"
#import <CoreData/CoreData.h>

@class ContactEntity;

@interface WorkContactTableDataSource : NSObject <ContactGroupDataSource>

+ (instancetype)workContactTableDataSource;
+ (instancetype)workContactTableDataSourceWithMembers:(NSMutableSet *)members;
+ (instancetype)workContactTableDataSourceWithFetchedResultsControllerDelegate:(id<NSFetchedResultsControllerDelegate>)delegate members:(NSMutableSet *)members;

@property (nonatomic) BOOL excludeGatewayContacts;
@property (nonatomic) BOOL excludeEchoEcho;

- (ContactEntity *)workContactAtIndexPath:(NSIndexPath *)indexPath;

- (NSIndexPath *)indexPathForObject:(id)object;

- (NSSet *)getSelectedWorkContacts;

- (void)updateSelectedWorkContacts:(NSSet *)contacts;

- (void)refreshWorkContactSortIndices;

- (NSUInteger)countOfWorkContacts;

@end

