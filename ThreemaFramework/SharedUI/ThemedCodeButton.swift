import UIKit

/// Base class for `UIButton`s that are implemented in code
///
/// It provides a color method to update your colors on theme changes (`updateColors()`)
/// and a default action that gets called when the button is tapped (`Action`).
///
/// If you don't need more information during initialization you can just override `configureButton()`.
open class ThemedCodeButton: UIButton {
    public typealias Action = (ThemedCodeButton) -> Void
    
    private let action: Action
    
    // MARK: - Lifecycle
    
    public init(frame: CGRect = .zero, action: @escaping Action) {
        self.action = action
        
        super.init(frame: frame)
        
        configureButton()
        registerObserver()
        updateColors()
    }
    
    @available(*, unavailable)
    override init(frame: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Called during initialization
    open func configureButton() {
        addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }
    
    private func registerObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorThemeChanged),
            name: NSNotification.Name(rawValue: kNotificationColorThemeChanged),
            object: nil
        )
    }
    
    // MARK: - Update
    
    /// Called whenever the colors of the button should be set to the current theme colors
    open func updateColors() { }
    
    // MARK: - Action
    
    @objc private func buttonTapped() {
        action(self)
    }
    
    // MARK: - Notification
    
    @objc private func colorThemeChanged() {
        updateColors()
    }
}
