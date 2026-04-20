#import <Foundation/Foundation.h>
#import "ContactGroupDataSource.h"
#import <CoreData/CoreData.h>
#import "ThreemaFramework/ThreemaFramework-Swift.h"

@interface GroupTableDataSource : NSObject <ContactGroupDataSource>

+ (instancetype)groupTableDataSource;

+ (instancetype)groupTableDataSourceWithFetchedResultsControllerDelegate:(id<NSFetchedResultsControllerDelegate>)delegate;

- (Group *)groupAtIndexPath:(NSIndexPath *)indexPath;

- (NSIndexPath *)indexPathForObject:(id)object;

@end
