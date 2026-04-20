import Foundation

/// A `UILabel` subclass which automatically changes its textAlignment based on its content
class RTLAligningLabel: UILabel {
    override public var text: String? {
        didSet {
            guard let text,
                  !text.isEmpty else {
                return
            }
            textAlignment = text.textAlignment
        }
    }
    
    override public var attributedText: NSAttributedString? {
        didSet {
            guard let text,
                  !text.isEmpty else {
                return
            }
            textAlignment = text.textAlignment
        }
    }
}
