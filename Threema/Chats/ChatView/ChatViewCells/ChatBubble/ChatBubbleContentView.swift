import Foundation

/// A view which returns the current `frame` each time either `bounds` or `frame` change
final class ChatBubbleContentView: UIView {
    
    var frameDidChange: (CGRect) -> Void
    
    override var frame: CGRect {
        didSet {
            if oldValue != frame {
                frameDidChange(frame)
            }
        }
    }
    
    override var bounds: CGRect {
        didSet {
            if oldValue != bounds {
                frameDidChange(frame)
            }
        }
    }
    
    init(frameDidChange: @escaping ((CGRect) -> Void)) {
        self.frameDidChange = frameDidChange
        
        super.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
