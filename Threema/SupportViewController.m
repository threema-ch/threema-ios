//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2012-2022 Threema GmbH
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

#import "SupportViewController.h"
#import "MyIdentityStore.h"
#import "Utils.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "BundleUtil.h"

@interface SupportViewController ()

@end

@implementation SupportViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.webView = [[WKWebView alloc] initWithFrame:self.view.frame];
    self.webView.allowsLinkPreview = NO;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.navigationDelegate = self;
    [self.view addSubview:self.webView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSURL *supportUrl = nil;
    
    if ([MyIdentityStore sharedMyIdentityStore].licenseSupportUrl.length > 0) {
        supportUrl = [NSURL URLWithString:[MyIdentityStore sharedMyIdentityStore].licenseSupportUrl];
    }
    
    if (supportUrl == nil) {
        NSMutableArray *queryItems = [[NSMutableArray alloc] init];
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"lang" value:[[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0]]];
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"version" value:[Utils getClientVersion]]];
        [queryItems addObject:[NSURLQueryItem queryItemWithName:@"identity" value:[MyIdentityStore sharedMyIdentityStore].identity]];
        
        NSURLComponents *components = [NSURLComponents componentsWithString:[BundleUtil objectForInfoDictionaryKey:@"ThreemaSupportURL"]];
        components.queryItems = queryItems;
        supportUrl = components.URL;
    }
    
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [self.webView loadRequest:[NSURLRequest requestWithURL:supportUrl cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15]];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [MBProgressHUD hideHUDForView:self.view animated:YES];    
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
        if (navigationAction.request.URL != nil) {
            [[UIApplication sharedApplication] openURL:navigationAction.request.URL options:@{} completionHandler:nil];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (SYSTEM_IS_IPAD) {
        return UIInterfaceOrientationMaskAll;
    }
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end
