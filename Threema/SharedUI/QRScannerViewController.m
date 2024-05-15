//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2014-2024 Threema GmbH
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

#import "QRScannerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MBProgressHUD/MBProgressHUD.h>
#import "Threema-Swift.h"

#ifdef DEBUG
  static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
  static const DDLogLevel ddLogLevel = DDLogLevelWarning;
#endif
#define MEDIA_TYPE AVMediaTypeVideo

@interface Barcode : NSObject
@property (nonatomic, strong) AVMetadataMachineReadableCodeObject *metadataObject;
@property (nonatomic, strong) UIBezierPath *cornersPath;
@property (nonatomic, strong) UIBezierPath *boundingBoxPath;
@end

@implementation Barcode
@end

@implementation QRScannerViewController {
    AVCaptureSession *_captureSession;
    AVCaptureDevice *_videoDevice;
    AVCaptureDeviceInput *_videoInput;
    AVCaptureVideoPreviewLayer *_previewLayer;
    AVCaptureMetadataOutput *_metadataOutput;
    BOOL _running;
    
    NSMutableDictionary *_barcodes;
    CGFloat _initialPinchZoom;
}

#pragma mark -

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelScan)];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    self.view.backgroundColor = [UIColor blackColor];
    self.previewView = [[UIView alloc] initWithFrame:self.view.bounds];
    if (self.view != nil) {
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    }
    [self.view addSubview:self.previewView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([self hasCameraAccess]) {
        [self setupCaptureSession];
    }
    
    _barcodes = [NSMutableDictionary new];
    
    self.navigationController.presentationController.delegate = self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startRunning];
    [self updateOrientation];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopRunning];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    CGAffineTransform targetRotation = [coordinator targetTransform];
    CGAffineTransform inverseRotation = CGAffineTransformInvert(targetRotation);

    [coordinator animateAlongsideTransition:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {

        self.previewView.transform = CGAffineTransformConcat(self.previewView.transform, inverseRotation);

        self.previewView.frame = self.view.bounds;
    } completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
    }];
}

#pragma mark - Notifications

- (void)applicationWillEnterForeground:(NSNotification*)note {
    [self startRunning];
}

- (void)applicationDidEnterBackground:(NSNotification*)note {
    [self stopRunning];
}

#pragma mark - Actions

- (void)cancelScan {
    [self.delegate qrScannerViewController:self didCancelAndWillDismissItself:NO];
}

- (void)pinchDetected:(UIPinchGestureRecognizer*)recogniser {
    if (!_videoDevice) return;
    
    if (recogniser.state == UIGestureRecognizerStateBegan) {
        _initialPinchZoom = _videoDevice.videoZoomFactor;
    }
    
    NSError *error = nil;
    [_videoDevice lockForConfiguration:&error];
    
    if (!error) {
        CGFloat zoomFactor;
        CGFloat scale = recogniser.scale;
        if (scale < 1.0f) {
            zoomFactor = _initialPinchZoom - pow(_videoDevice.activeFormat.videoMaxZoomFactor, 1.0f - recogniser.scale);
        } else {
            zoomFactor = _initialPinchZoom + pow(_videoDevice.activeFormat.videoMaxZoomFactor, (recogniser.scale - 1.0f) / 2.0f);
        }
        
        zoomFactor = MIN(10.0f, zoomFactor);
        zoomFactor = MAX(1.0f, zoomFactor);
        
        _videoDevice.videoZoomFactor = zoomFactor;
        
        [_videoDevice unlockForConfiguration];
    }
}


#pragma mark - Video stuff

- (void)startRunning {
    NSArray *allSublayers = [_previewView.layer.sublayers copy];
    [allSublayers enumerateObjectsUsingBlock:^(CALayer *layer, __unused NSUInteger idx, __unused BOOL *stop) {
        if (layer != _previewLayer) {
            [layer removeFromSuperlayer];
        }
    }];
    if (_captureSession) {
        if (_running) return;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [_captureSession startRunning];
        });
        _metadataOutput.metadataObjectTypes = _metadataOutput.availableMetadataObjectTypes;
        
        if ([[VoIPCallStateManager shared] currentCallState] == CallStateIdle) {
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient withOptions:0 error:nil];
            [[AVAudioSession sharedInstance] setActive:YES error:nil];
        }
        
        _running = YES;
    }
}

- (void)stopRunning {
    if (_captureSession) {
        if (!_running) return;
        [_captureSession stopRunning];
        if ([[VoIPCallStateManager shared] currentCallState] == CallStateIdle) {
            [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        }
        _running = NO;
    }
}

- (BOOL)hasCameraAccess {
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:MEDIA_TYPE];
    if (authStatus == AVAuthorizationStatusAuthorized) {
        return YES;
    } else if(authStatus == AVAuthorizationStatusDenied || authStatus == AVAuthorizationStatusRestricted){
        [self showCameraAccessAlert];
    } else if(authStatus == AVAuthorizationStatusNotDetermined){
        [AVCaptureDevice requestAccessForMediaType:MEDIA_TYPE completionHandler:^(BOOL granted) {
            if(granted){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self setupCaptureSession];
                    [self startRunning];
                });
            } else {
                DDLogError(@"Camera access not granted");
            }
        }];
    }
    
    return NO;
}

- (void)updateOrientation {
    AVCaptureConnection* connection = _previewLayer.connection;
    if (connection && connection.isVideoOrientationSupported) {
        UIDeviceOrientation orientation = UIDevice.currentDevice.orientation;
        switch (orientation) {
            case UIDeviceOrientationPortrait:
                [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
                break;
                
            case UIDeviceOrientationPortraitUpsideDown:
                [connection setVideoOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
                break;
                
            case UIDeviceOrientationLandscapeLeft:
                [connection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
                break;
                
            case UIDeviceOrientationLandscapeRight:
                [connection setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
                break;
                
            case UIDeviceOrientationUnknown:
            case UIDeviceOrientationFaceUp:
            case UIDeviceOrientationFaceDown:
                [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
                break;
        }
        _previewLayer.frame = _previewView.frame;
    }
}

- (void)showCameraAccessAlert {
    // Show access prompt
    [UIAlertTemplate showOpenSettingsAlertWithOwner:self noAccessAlertType:NoAccessAlertTypeCamera];
}

- (void)setupCaptureSession {
    if (_captureSession) return;
    
    _videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:MEDIA_TYPE];
    if (!_videoDevice) {
        DDLogError(@"No video camera on this device!");
        return;
    }
    
    _captureSession = [[AVCaptureSession alloc] init];
    
    _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_videoDevice error:nil];
    
    if ([_captureSession canAddInput:_videoInput]) {
        [_captureSession addInput:_videoInput];
    }
    
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    _previewLayer.frame = _previewView.bounds;
    [_previewView.layer addSublayer:_previewLayer];
    
    [_previewView addGestureRecognizer:[[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchDetected:)]];
    _metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    
    dispatch_queue_t metadataQueue = dispatch_queue_create("ch.threema.app.qrmetadata", 0);
    [_metadataOutput setMetadataObjectsDelegate:self queue:metadataQueue];
    
    if ([_captureSession canAddOutput:_metadataOutput]) {
        [_captureSession addOutput:_metadataOutput];
    }
}


#pragma mark -

- (Barcode*)processMetadataObject:(AVMetadataMachineReadableCodeObject*)code {
    if (code.stringValue == nil)
        return nil; /* e.g. when scanning binary data */
    
    Barcode *barcode = _barcodes[code.stringValue];
    
    if (!barcode) {
        barcode = [Barcode new];
        _barcodes[code.stringValue] = barcode;
    }
    
    barcode.metadataObject = code;
    
    // Create the path joining code's corners
    
    CGMutablePathRef cornersPath = CGPathCreateMutable();
    
    CGPoint point;
    CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)code.corners[0], &point);
    
    CGPathMoveToPoint(cornersPath, nil, point.x, point.y);
    
    for (int i = 1; i < code.corners.count; i++) {
        CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)code.corners[i], &point);
        CGPathAddLineToPoint(cornersPath, nil, point.x, point.y);
    }
    
    CGPathCloseSubpath(cornersPath);
    
    barcode.cornersPath = [UIBezierPath bezierPathWithCGPath:cornersPath];
    CGPathRelease(cornersPath);
    
    barcode.boundingBoxPath = [UIBezierPath bezierPathWithRect:code.bounds];
    
    return barcode;
}


#pragma mark - AVCaptureMetadataOutputObjectsDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    NSSet *originalBarcodes = [NSSet setWithArray:_barcodes.allValues];
    NSMutableSet *foundBarcodes = [NSMutableSet new];
    
    [metadataObjects enumerateObjectsUsingBlock:^(AVMetadataObject *obj, NSUInteger idx, BOOL *stop) {
        DDLogVerbose(@"Metadata: %@", obj);
        if ([obj isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            AVMetadataMachineReadableCodeObject *code = (AVMetadataMachineReadableCodeObject*)[_previewLayer transformedMetadataObjectForMetadataObject:obj];
            Barcode *barcode = [self processMetadataObject:code];
            if (barcode != nil)
                [foundBarcodes addObject:barcode];
        }
    }];
    
    NSMutableSet *newBarcodes = [foundBarcodes mutableCopy];
    [newBarcodes minusSet:originalBarcodes];
    
    NSMutableSet *goneBarcodes = [originalBarcodes mutableCopy];
    [goneBarcodes minusSet:foundBarcodes];
    
    [goneBarcodes enumerateObjectsUsingBlock:^(Barcode *barcode, BOOL *stop) {
        [_barcodes removeObjectForKey:barcode.metadataObject.stringValue];
    }];
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        // Remove all old layers
        NSArray *allSublayers = [_previewView.layer.sublayers copy];
        [allSublayers enumerateObjectsUsingBlock:^(CALayer *layer, NSUInteger idx, BOOL *stop) {
            if (layer != _previewLayer) {
                [layer removeFromSuperlayer];
            }
        }];
        
        // Add new layers
        [newBarcodes enumerateObjectsUsingBlock:^(Barcode *barcode, __unused BOOL *stop) {
            CAShapeLayer *cornersPathLayer = [CAShapeLayer new];
            cornersPathLayer.path = barcode.cornersPath.CGPath;
            cornersPathLayer.lineWidth = 2.0f;
            cornersPathLayer.strokeColor = [UIColor blueColor].CGColor;
            cornersPathLayer.fillColor = [UIColor colorWithRed:0.0f green:0.0f blue:1.0f alpha:0.5f].CGColor;
            [_previewView.layer addSublayer:cornersPathLayer];
        }];
        
        [newBarcodes enumerateObjectsUsingBlock:^(Barcode *barcode, BOOL *stop) {
            // call delegate with slight delay so that user can see our fancy box
            [self stopRunning];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self.delegate qrScannerViewController:self didScanResult:barcode.metadataObject.stringValue];
            });
           
        }];
       
        
    });
}

#pragma mark - UIAdaptivePresentationControllerDelegate

- (void)presentationControllerWillDismiss:(UIPresentationController *)presentationController
{
    [self.delegate qrScannerViewController:self didCancelAndWillDismissItself:YES];
}

@end
