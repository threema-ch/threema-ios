#import <Foundation/Foundation.h>

@interface URLSenderItem : NSObject

@property (readonly) NSString *type;
@property (readonly) NSURL *url;
@property (readonly) BOOL sendAsFile;
@property (nonatomic, readwrite) NSString *caption;
@property (nonatomic, readwrite) NSNumber *duration;
@property (readonly) NSNumber *renderType;

+(instancetype)itemWithUrl:(NSURL *)url type:(NSString *)type renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile;

+(instancetype)itemWithData:(NSData *)data fileName:(NSString *)fileName type:(NSString *)type renderType:(NSNumber *)renderType sendAsFile:(BOOL)sendAsFile;

- (NSData *)getData;

- (NSString *)getName;

- (NSString *)getMimeType;

- (UIImage *)getThumbnail;

- (CGFloat)getDuration;
- (CGFloat)getHeight;
- (CGFloat)getWidth;

@end
