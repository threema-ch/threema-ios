#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BundleUtil : NSObject

+ (nullable NSBundle *)frameworkBundle;

/// In an extension this returns `nil` if the main app is fully terminated, but might return the main bundle if the app is just backgrounded
+ (nullable NSBundle *)mainBundle;

+ (nullable NSString *)threemaAppGroupIdentifier;

+ (nullable NSString *)threemaAppIdentifier;

+ (nullable NSString *)targetManagerKey;

+ (nullable id)objectForInfoDictionaryKey:(NSString *)key;

+ (id)objectForThreemaFrameworkConfigurationKey:(NSString *)key;

+ (nullable NSString *)pathForResource:(nullable NSString *)resource ofType:(nullable NSString *)type;

+ (nullable NSURL *)URLForResource:(nullable NSString *)resourceName withExtension:(nullable NSString *)extension;

+ (nullable UIImage *)imageNamed:(NSString *)imageName;

+ (NSString *)localizedStringForKey:(NSString *)key;

+ (nullable UIView *)loadXibNamed:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
