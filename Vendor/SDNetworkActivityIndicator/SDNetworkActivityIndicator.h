/*
 * This file is part of the SDNetworkActivityIndicator package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>

@interface SDNetworkActivityIndicator : NSObject
{
    @private
    NSUInteger counter;
}

+ (id)sharedActivityIndicator;
- (void)startActivity;
- (void)stopActivity;
- (void)stopAllActivity;

@end
