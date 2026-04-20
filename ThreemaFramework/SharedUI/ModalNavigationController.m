#import "ModalNavigationController.h"

@interface ModalNavigationController () <UIGestureRecognizerDelegate>

@property UIBarButtonItem *doneButton;
@property UITapGestureRecognizer *tapGesture;
@property(nonatomic, getter=isModalInPresentation) BOOL modalInPresentation;

@end

@implementation ModalNavigationController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (_showDoneButton || _showLeftDoneButton) {
        [self setupDoneButton];
    }
}

- (void)setupDoneButton {
    _doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
    
    if (_showLeftDoneButton) {
        self.topViewController.navigationItem.leftBarButtonItem = _doneButton;
    } else {
        self.topViewController.navigationItem.rightBarButtonItem = _doneButton;
    }
}

- (void)setupTapGesture {
    if (_tapGesture == nil) {
        _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(windowTapped:)];
        [_tapGesture setNumberOfTapsRequired:1];
        _tapGesture.cancelsTouchesInView = NO;
        [_tapGesture setDelegate:self];
    }
    
    [self.view.window addGestureRecognizer:_tapGesture];
}

- (void)cleanup {
    [self.view.window removeGestureRecognizer:_tapGesture];
    if (_doneButton) {
        _doneButton = nil;
        if (_showLeftDoneButton) {
            self.topViewController.navigationItem.leftBarButtonItem = nil;
        } else {
            self.topViewController.navigationItem.rightBarButtonItem = nil;
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [self cleanup];
    
    if (_modalDelegate) {
        [_modalDelegate didDismissModalNavigationController];
    }
    [super viewDidDisappear:animated];
}

- (UIModalPresentationStyle)modalPresentationStyle {
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular
        && _showFullScreenOnIPad == YES)
    {
        return UIModalPresentationFullScreen;
    }

    return [super modalPresentationStyle];
}
- (void)setModalInPresentation:(BOOL)modalInPresentation {
    _modalInPresentation = modalInPresentation;
}

- (void)setDismissOnTapOutside:(BOOL)dismissOnTapOutside {
    self.modalInPresentation = !dismissOnTapOutside;
}

- (CGSize)preferredContentSize {
    return self.topViewController.preferredContentSize;
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular) {
        return UIInterfaceOrientationMaskAll;
    }
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

#pragma mark - navigation button

- (void)done:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIGestureRecognizer Recognizer

- (void)windowTapped:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded)
    {
        CGPoint location = [sender locationInView:self.view];
        
        if (![self.view pointInside:location withEvent:nil] && _dismissOnTapOutside) {
            [self done:nil];
            }
        }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (self.presentedViewController.popoverPresentationController != nil) {
        return NO;
    }
    return YES;
}

@end
