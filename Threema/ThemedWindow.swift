import ThreemaFramework
import UIKit

/// This UIWindow subclass observes changes in the system user interface style (light, dark, or unspecified).
/// When the system appearance changes, it updates the app's color theme using the Colors utility.
final class ThemedWindow: UIWindow {

    // MARK: - Super class overrides

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        setupThemeObservation()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupThemeObservation()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupThemeObservation()
    }

    // MARK: - Private methods

    private func setupThemeObservation() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (current: Self, previous) in
            guard let self else {
                return
            }
            guard previous.userInterfaceStyle != current.traitCollection.userInterfaceStyle else {
                return
            }
            Colors.resolveTheme()
            Colors.update(window: self)
        }
    }
}
