#import "PhoneNumberNormalizer.h"
#import "NBPhoneNumberUtil.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import "NBMetadataHelper.h"

@interface PhoneNumberNormalizer ()

@property NBPhoneNumberUtil *phoneNumberUtil;

@end

@implementation PhoneNumberNormalizer

+ (PhoneNumberNormalizer*)sharedInstance {
    static PhoneNumberNormalizer *sharedInstance;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        sharedInstance = [[PhoneNumberNormalizer alloc] init];
        
        sharedInstance.phoneNumberUtil = [NBPhoneNumberUtil sharedInstance];
    });
    return sharedInstance;
}

- (NSString*)phoneNumberToE164:(NSString*)phoneNumber withDefaultRegion:(NSString*)defaultRegion prettyFormat:(NSString**)prettyFormat {
    
    NSError *error = nil;
    NBPhoneNumber *parsed = [_phoneNumberUtil parse:phoneNumber defaultRegion:defaultRegion error:&error];
    if (parsed == nil)
        return nil;
    
    NSString *e164WithPlus = [_phoneNumberUtil format:parsed numberFormat:NBEPhoneNumberFormatE164 error:&error];
    if (e164WithPlus == nil)
        return nil;
    
    NSString *result = [e164WithPlus stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"+"]];
    
    if (prettyFormat != nil)
        *prettyFormat = [_phoneNumberUtil format:parsed numberFormat:NBEPhoneNumberFormatINTERNATIONAL error:&error];
    
    return result;
}

- (NSString *)examplePhoneNumberForRegion:(NSString *)region {
    
    NSError *error = nil;
    
    NBPhoneNumber *exampleNumber = [_phoneNumberUtil getExampleNumber:region error:&error];
    if (exampleNumber == nil)
        return nil;
    
    return [_phoneNumberUtil format:exampleNumber numberFormat:NBEPhoneNumberFormatNATIONAL error:&error];
}

- (NSString *)exampleRegionalPhoneNumberForRegion:(NSString *)region {
    
    NSError *error = nil;
    
    NBPhoneNumber *exampleNumber = [_phoneNumberUtil getExampleNumber:region error:&error];
    if (exampleNumber == nil) {
        return nil;
    }
    
    NSString *number = [_phoneNumberUtil format:exampleNumber numberFormat:NBEPhoneNumberFormatINTERNATIONAL error:&error];

    return [self regionalPartForPhoneNumber:number];
}

- (NSString *)regionalPartForPhoneNumber:(NSString *)phoneNumber {
    NSString *region = [self regionForPhoneNumber:phoneNumber];
    if (region) {
        NBMetadataHelper *metadataHelper = [[NBMetadataHelper alloc] init];
        NSString *code = [[metadataHelper countryCodeToCountryNumberDictionary] objectForKey:region];
    
        NSRange codeRange = [phoneNumber rangeOfString:code];
        if (codeRange.location != NSNotFound) {
            return [phoneNumber substringFromIndex:codeRange.location + codeRange.length];
        }
    }
    
    return phoneNumber;
}

- (NSString *)regionForPhoneNumber:(NSString *)phoneNumber {
    NSError *error = nil;
    
    NSString *defaultRegion = [PhoneNumberNormalizer userRegion];
    NBPhoneNumber *parsed = [_phoneNumberUtil parse:phoneNumber defaultRegion:defaultRegion error:&error];
    if (parsed == nil) {
        return nil;
    }
    
    return [_phoneNumberUtil getRegionCodeForNumber:parsed];
}

+ (NSString*)userRegion {
    /* try CTCarrier first as it's probably more reliable (who knows what the user's country setting may be) */
    CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc] init];
    NSDictionary<NSString *, CTCarrier *> *carriers = [netInfo serviceSubscriberCellularProviders];
    for (CTCarrier *carrier in carriers.allValues) {
        // Since iOS 16 is this function deprecated. It will return always "--".
        if (carrier.isoCountryCode != nil && ![carrier.isoCountryCode isEqualToString:@"--"]) {
            return [carrier.isoCountryCode uppercaseString];
        }
    }
    
    /* fall back to NSLocale */
    return [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
}

@end
