import Foundation

/// A `UITextView` subclass which automatically changes its textAlignment based on its content
/// This currently does not work for interactive UITextViews where the user can switch the input method
/// without having entered any text. See `ChatTextView` for how interactive UITextViews are handled.
/// It probably makes sense to handle interactive text views here as well instead of duplicating code.
class RTLAligningTextView: UITextView {
    override public var text: String! {
        didSet {
            if !text.isEmpty {
                textAlignment = text.textAlignment
            }
        }
    }

    override public var attributedText: NSAttributedString! {
        didSet {
            let text = attributedText.string
            if !text.isEmpty {
                textAlignment = text.textAlignment
            }
        }
    }

    // TODO: (IOS-4156) All code below is needed due to a bug which causes text to be cut of when the device language is set to german. The changes enforce the use of TextKit1. Last tested iOS 17.4.1
    var customLayoutManager = NSLayoutManager()

    override var layoutManager: NSLayoutManager {
        customLayoutManager
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        initCustomLayoutManager()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initCustomLayoutManager()
    }

    private func initCustomLayoutManager() {
        customLayoutManager.textStorage = textStorage
        customLayoutManager.addTextContainer(textContainer)
        
        textContainer.replaceLayoutManager(customLayoutManager)
    }
}
