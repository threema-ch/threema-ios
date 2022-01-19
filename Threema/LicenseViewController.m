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

#import "LicenseViewController.h"
#import "BundleUtil.h"

@interface LicenseViewController () <WKNavigationDelegate>

@end

@implementation LicenseViewController

static NSString *licenseFile = @"license.html";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [Colors background];
    
    WKPreferences *webprefs = [[WKPreferences alloc] init];
    webprefs.javaScriptEnabled = NO;
    WKWebViewConfiguration *webconfig = [[WKWebViewConfiguration alloc] init];
    webconfig.preferences = webprefs;
    self.webView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:webconfig];
    self.webView.allowsLinkPreview = NO;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.opaque = false;
    [self.view addSubview:self.webView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    NSString *licenseFilePath = [BundleUtil pathForResource:licenseFile ofType:nil];
    NSString *path = [[NSBundle mainBundle] bundlePath];
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    NSString *htmlString = [NSString stringWithContentsOfFile:licenseFilePath encoding:NSUTF8StringEncoding error:nil];
    self.webView.backgroundColor = [Colors backgroundDark];
    self.webView.navigationDelegate = self;

    switch ([Colors getTheme]) {
        case ColorThemeDark:
        case ColorThemeDarkWork:
            htmlString = [htmlString stringByReplacingOccurrencesOfString:@"/*backgroundcolor*/background-color: white;/*backgroundcolor*/" withString:@"background-color: #333"];
            htmlString = [htmlString stringByReplacingOccurrencesOfString:@"/*fontcolor*/color: black;/*fontcolor*/" withString:@"color: white"];
            htmlString = [htmlString stringByReplacingOccurrencesOfString:@"/*titlefontcolor*/color: #555;/*titlefontcolor*/" withString:@"color: #CCC;"];
            htmlString = [htmlString stringByReplacingOccurrencesOfString:@"/*titlefontcolor*/color: #777;/*titlefontcolor*/" withString:@"color: #AAA;"];
            break;
        case ColorThemeLight:
        case ColorThemeLightWork:
        case ColorThemeUndefined:
            break;
    }
    
    // Replace copyright year placeholder with current year
    NSString *currentYearString = [DateFormatter getYearFor:[NSDate date]];
    htmlString = [htmlString stringByReplacingOccurrencesOfString:@"/*threemalicensetoyear*/" withString:currentYearString];
    
    [self.webView loadHTMLString:htmlString baseURL:baseURL];
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

@end
