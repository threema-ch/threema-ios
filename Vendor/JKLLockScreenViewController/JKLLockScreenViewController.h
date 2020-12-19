// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema GmbH and licensed under the AGPLv3.

//
//  JKLLockScreenViewController.h
//  JKLib
//
//  @date   2015. 03. 25.
//  @author Choi JoongKwan
//  @email  joongkwan.choi@gmail.com
//  @brief  Lock Screen View Controller class
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, LockScreenMode) {
    LockScreenModeNormal = 0,       // [일반 모드]
    LockScreenModeNew,              // [신규 모드]
    LockScreenModeChange,           // [변경 모드]
    LockScreenModeVerification,     // [확인 모드]
    //------------------ Threema edit begin ---------------------------
    LockScreenModeChangeCheck,
    LockScreenModeDisable,
    LockScreenModeExtension,
    //------------------ Threema edit end ---------------------------
};

@protocol JKLLockScreenViewControllerDelegate;
@protocol JKLLockScreenViewControllerDataSource;

@interface JKLLockScreenViewController : UIViewController

@property (nonatomic, unsafe_unretained) LockScreenMode lockScreenMode;
@property (nonatomic, weak) IBOutlet id<JKLLockScreenViewControllerDelegate> delegate;
@property (nonatomic, weak) IBOutlet id<JKLLockScreenViewControllerDataSource> dataSource;

/**
 *  Tint color for the buttons
 */
@property (nonatomic, weak) UIColor *tintColor;

@end

@protocol JKLLockScreenViewControllerDelegate <NSObject>
@optional
- (void)unlockWasSuccessfulLockScreenViewController:(JKLLockScreenViewController *)lockScreenViewController pincode:(NSString *)pincode;    // support for number
- (void)unlockWasSuccessfulLockScreenViewController:(JKLLockScreenViewController *)lockScreenViewController;                                // support for touch id
- (void)unlockWasCancelledLockScreenViewController:(JKLLockScreenViewController *)lockScreenViewController;
- (void)unlockWasFailureLockScreenViewController:(JKLLockScreenViewController *)lockScreenViewController;

//------------------ Threema edit begin ---------------------------
- (void)didPasscodeEnteredCorrectly:(JKLLockScreenViewController*)viewController;
- (void)didPasscodeEnteredIncorrectly:(JKLLockScreenViewController*)viewController;
- (void)shouldEraseApplicationData:(JKLLockScreenViewController*)viewController;
- (void)didSettingsChanged:(JKLLockScreenViewController*)viewController;
- (void)didPasscodeViewDismiss:(JKLLockScreenViewController*)viewController;
//------------------ Threema edit end ---------------------------

@end

@protocol JKLLockScreenViewControllerDataSource <NSObject>
@required
- (BOOL)lockScreenViewController:(JKLLockScreenViewController *)lockScreenViewController pincode:(NSString *)pincode;
@optional
- (BOOL)allowTouchIDLockScreenViewController:(JKLLockScreenViewController *)lockScreenViewController;
@end
