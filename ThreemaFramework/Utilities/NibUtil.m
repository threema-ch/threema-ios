#import "NibUtil.h"

@implementation NibUtil

+ (UIView *) loadViewFromNibWithName: (NSString *) name
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSArray *nibs =  [bundle loadNibNamed: name owner:self options:nil];
    UIView *view = [nibs objectAtIndex:0];
    
    return view;
}

@end
