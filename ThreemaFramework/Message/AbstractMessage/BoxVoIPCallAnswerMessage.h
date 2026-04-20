#import <ThreemaFramework/AbstractMessage.h>

@interface BoxVoIPCallAnswerMessage : AbstractMessage

@property NSData *jsonData;
@property BOOL isUserInteraction;

@end
