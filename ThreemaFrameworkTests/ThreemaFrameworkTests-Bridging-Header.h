// Test-only Obj-C API exposed to the ThreemaFrameworkTests Swift target.
//
// The `MDMSetup (Testing)` category below is declared only here (the test target's bridging header),
// so its methods are callable from tests but not from the app. The implementations live in the
// framework (`MDMSetup.m`); this declaration just makes the selectors visible to the test module.
@import ThreemaFramework;

// A forward declaration is enough for the parameter types of a method signature.
@protocol UserSettingsProtocol;
@protocol LicenseStoreProtocol;
@protocol MyIdentityStoreProtocol;

@interface MDMSetup (Testing)

- (nonnull instancetype)initForTestWithAppSetupStateRawValue:(NSInteger)appSetupStateRawValue
                                              isBusinessApp:(BOOL)businessApp
                                                   isOnPrem:(BOOL)onPrem
                                               userSettings:(nonnull id<UserSettingsProtocol>)userSettings
                                               licenseStore:(nonnull id<LicenseStoreProtocol>)licenseStore
                                            myIdentityStore:(nonnull id<MyIdentityStoreProtocol>)myIdentityStore;

@end
