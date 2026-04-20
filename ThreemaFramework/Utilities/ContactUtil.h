#import <Foundation/Foundation.h>
#import <Contacts/Contacts.h>

@interface ContactUtil : NSObject

+ (NSMutableString *)nameFromFirstname:(NSString *)firstName lastname:(NSString *)lastName;

+ (NSString *)getNameFromVCardData:(NSData *)data;

+ (UIViewController *)getContactViewControllerForVCardData:(NSData *)data;

+ (NSData *)vCardDataForCnContact:(CNContact *)contact;

@end
