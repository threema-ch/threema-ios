#import <Foundation/Foundation.h>
#import "ContactGroupDataSource.h"
#import <CoreData/CoreData.h>

@class DistributionListEntity;

@interface DistributionListTableDataSource : NSObject <ContactGroupDataSource>

+ (instancetype)distributionListDataSource;
+ (instancetype)distributionListSourceWithMembers:(NSMutableSet *)members;
+ (instancetype)distributionListTableDataSourceWithFetchedResultsControllerDelegate:(id<NSFetchedResultsControllerDelegate>)delegate members:(NSMutableSet *)members;

@property (nonatomic) BOOL excludeGatewayContacts;
@property (nonatomic) BOOL excludeEchoEcho;

- (DistributionListEntity *)distributionListAtIndexPath:(NSIndexPath *)indexPath;

- (NSIndexPath *)indexPathForObject:(id)object;

- (NSSet *)getSelectedDistributionLists;

- (void)updateSelectedDistributionLists:(NSSet *)distributionLists;

- (NSUInteger)countOfDistributionLists;

@end
