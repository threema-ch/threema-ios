//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2013-2022 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#import "SSLCAHelper.h"
#import "BundleUtil.h"
@import TrustKit;

@implementation SSLCAHelper

+ (void)initTrustKit {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *trustKitConfig = @{
            kTSKSwizzleNetworkDelegates: @NO,
            kTSKPinnedDomains: @{
                    @"threema.ch" : @{
                            kTSKIncludeSubdomains: @YES,
                            kTSKPublicKeyHashes : @[
                                    @"8SLubAXo6MrrGziVya6HjCS/Cuc7eqtzw1v6AfIW57c=",
                                    @"8kTK9HP1KHIP0sn6T2AFH3Bq+qq3wn2i/OJSMjewpFw=",
                                    @"KKBJHJn1PQSdNTmoAfhxqWTO61r8O8bPi/JeGtP/6gg=",
                                    @"h2gHawxPZyMCiZSkJN0dQ4RsDxowVuTmuiNQyjeU+Sk=",
                                    @"HXqz8rMr6nBDdUX3CdyIwln8ym3qFUBwv4QGyMN2uEg=",
                                    @"2Vpy8qUQCqc2+Lg6BgRO8G6e6vh7NmvVHTljfwP/Pfk=",
                                    @"vGQZ8hm2h+km+q7rnJ7kF9S17BwSY0rbhwjz6nIupf0=",
                                    @"jsQHAHKQ2oOf3rvMn9GJVIKslkhLpODGOMPSxgLeIyo="
                            ],
                            kTSKEnforcePinning : @YES,
                            kTSKReportUris: @[
                                    @"https://3ma.ch/pinreport"
                            ],
                            kTSKDisableDefaultReportUri: @YES
                    },
                    
            }
        };
        [TrustKit initSharedInstanceWithConfiguration:trustKitConfig];
    });
}

+ (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

+ (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [SSLCAHelper initTrustKit];
    TSKPinningValidator *pinningValidator = [[TrustKit sharedInstance] pinningValidator];
    // Pass the authentication challenge to the validator; if the validation fails, the connection will be blocked
    [pinningValidator handleChallenge:challenge completionHandler:^(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential) {
        switch (disposition) {
            case NSURLSessionAuthChallengeUseCredential:
                [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
                break;
            case NSURLSessionAuthChallengePerformDefaultHandling:
                [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
                break;
            case NSURLSessionAuthChallengeCancelAuthenticationChallenge:
                [challenge.sender cancelAuthenticationChallenge:challenge];
                break;
            case NSURLSessionAuthChallengeRejectProtectionSpace:
                [challenge.sender rejectProtectionSpaceAndContinueWithChallenge:challenge];
                break;
            default:
                [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
                break;
        }
    }];
}

+ (void)session:(NSURLSession *)session didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completion:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completion {
    [SSLCAHelper initTrustKit];
    TSKPinningValidator *pinningValidator = [[TrustKit sharedInstance] pinningValidator];
    // Pass the authentication challenge to the validator; if the validation fails, the connection will be blocked
    [pinningValidator handleChallenge:challenge completionHandler:^(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential) {
        switch (disposition) {
            case NSURLSessionAuthChallengeUseCredential:
                [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
                break;
            case NSURLSessionAuthChallengePerformDefaultHandling:
                if ([challenge.sender respondsToSelector:@selector(performDefaultHandlingForAuthenticationChallenge:)]) {
                    [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
                }
                break;
            case NSURLSessionAuthChallengeCancelAuthenticationChallenge:
                [challenge.sender cancelAuthenticationChallenge:challenge];
                break;
            case NSURLSessionAuthChallengeRejectProtectionSpace:
                [challenge.sender rejectProtectionSpaceAndContinueWithChallenge:challenge];
                break;
            default:
                [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
                break;
        }
        completion(disposition, credential);
    }];
}

@end
