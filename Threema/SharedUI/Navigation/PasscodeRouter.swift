import ThreemaFramework

protocol PasscodeRouterProtocol: AnyObject {
    var lockScreen: LockScreen { get }
    var isPasscodeRequired: () -> Bool { get }
    var rootViewController: () -> UIViewController { get }
    
    func requireAuthenticationIfNeeded(
        style: UIModalPresentationStyle,
        onCancel: @escaping () -> Void,
        onSuccess: @escaping () -> Void
    )
}

extension PasscodeRouterProtocol {
    func requireAuthenticationIfNeeded(
        style: UIModalPresentationStyle = .automatic,
        onCancel: @escaping () -> Void = { },
        onSuccess: @escaping () -> Void
    ) {
        guard isPasscodeRequired() else {
            onSuccess()
            return
        }
        
        lockScreen.presentLockScreenView(
            viewController: rootViewController(),
            style: style,
            unlockCancelled: onCancel,
            didDismissAfterSuccess: onSuccess
        )
    }
}

final class PasscodeRouter: PasscodeRouterProtocol {
    let lockScreen: LockScreen
    let isPasscodeRequired: () -> Bool
    let rootViewController: () -> UIViewController
    
    init(
        lockScreen: LockScreen,
        isPasscodeRequired: @autoclosure @escaping () -> Bool,
        rootViewController: @autoclosure @escaping () -> UIViewController
    ) {
        self.lockScreen = lockScreen
        self.isPasscodeRequired = isPasscodeRequired
        self.rootViewController = rootViewController
    }
}
