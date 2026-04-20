#import "LinkIDCountryPickerRowView.h"

@implementation LinkIDCountryPickerRowView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        CGFloat nameWidth = frame.size.width * 0.8;
        CGFloat codeWidth = frame.size.width - nameWidth;
        
        CGFloat height = frame.size.height;
        CGFloat x = 16.0;
        
        _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, 0.0, nameWidth, height)];
        _nameLabel.textColor = [UIColor whiteColor];
        _nameLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:16.0];
        [self addSubview:_nameLabel];
        
        _codeLabel = [[UILabel alloc] initWithFrame:CGRectMake(nameWidth, 0.0, codeWidth, height)];
        _codeLabel.textColor = [UIColor whiteColor];
        _codeLabel.font = _nameLabel.font;
        [self addSubview:_codeLabel];
    }
    
    return self;
}

@end
