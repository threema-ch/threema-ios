

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonCryptor.h>
#include "QR_Encode.h"
#import "DataMatrix.h"

const static int QR_ECLEVEL_AUTO =  0;
const static int QR_ECLEVEL_H =     QR_LEVEL_H;
const static int QR_ECLEVEL_M =     QR_LEVEL_M;
const static int QR_ECLEVEL_L =     QR_LEVEL_L;
const static int QR_ECLEVEL_Q =     QR_LEVEL_Q;

const static int QR_VERSION_AUTO =  -1;

const static int BITS_PER_BYTE =    8;
const static int BYTES_PER_PIXEL =  4;

const static unsigned char WHITE =  0xff;

@interface QREncoder : NSObject {
    
}

+ (DataMatrix*)encodeWithECLevel:(int)ecLevel version:(int)version string:(NSString *)string AESPassphrase:(NSString*)AESPassphrase;

+ (DataMatrix*)encodeWithECLevel:(int)ecLevel version:(int)version string:(NSString*)string;

+ (UIImage*)renderDataMatrix:(DataMatrix*)matrix imageDimension:(int)imageDimension;

+ (UIImage*)renderDataMatrix:(DataMatrix*)matrix imageDimension:(int)imageDimension transparent:(BOOL)transparent;

@end

void FLProviderReleaseData(void *info, const void *data, size_t size);
