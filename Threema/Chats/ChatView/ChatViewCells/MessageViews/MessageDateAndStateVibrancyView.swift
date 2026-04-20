import Foundation

final class MessageDateAndStateVibrancyView {
    /// Message to show date and state for
    ///
    /// Reset to update with current message information.
    var message: BaseMessageEntity? {
        didSet {
            guard let message else {
                return
            }
                    
            dateAndStateView.message = message
            blurEffectViewWorkaroundDateAndStateView.message = message
        }
    }
    
    /// The view that should be affected by the vibrancy configuration
    var vibrancyAffectedView: MessageDateAndStateView {
        dateAndStateView
    }
    
    /// The view that should not be affected by the vibrancy configuration
    var vibrancyUnaffectedView: MessageDateAndStateView {
        blurEffectViewWorkaroundDateAndStateView
    }
    
    private lazy var dateAndStateView = MessageDateAndStateView()
    private lazy var blurEffectViewWorkaroundDateAndStateView = MessageDateAndStateView()
     
    // MARK: - Updates
    
    func updateColors() {
        
        if UIAccessibility.isReduceTransparencyEnabled {
            blurEffectViewWorkaroundDateAndStateView.overrideColor = .secondaryLabel
        }
        else if UIAccessibility.isDarkerSystemColorsEnabled {
            blurEffectViewWorkaroundDateAndStateView.overrideColor = .label
        }
        else {
            blurEffectViewWorkaroundDateAndStateView.overrideColor = .clear
        }
    }
}
