import Foundation

/// Lines to the left and right of the text in the UnreadMessageLineCell
final class NewUnreadMessageLineLineView: UIView {
    
    // - MARK: Nested Types
    typealias Config = ChatViewConfiguration.UnreadMessageLine
    enum Side {
        case left
        case right
    }
    
    // - MARK: Private Properties
    
    private var side: Side
    
    private lazy var hairlineView: UIView = {
        let hairline = UIView()
        hairline.translatesAutoresizingMaskIntoConstraints = false
        
        hairline.backgroundColor = .tintColor
        
        addSubview(hairline)
        
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalTo: hairline.widthAnchor),
            hairline.heightAnchor.constraint(equalToConstant: Config.leftRightLineHeight),
            hairline.centerYAnchor.constraint(equalTo: self.centerYAnchor),
        ])
        
        /// Setup rounded corners
        hairline.layer.cornerRadius = Config.leftRightLineRadius
        hairline.layer.maskedCorners = []
        
        let leftCorners = [CACornerMask.layerMinXMaxYCorner, CACornerMask.layerMinXMinYCorner]
        let rightCorners = [CACornerMask.layerMaxXMaxYCorner, CACornerMask.layerMaxXMinYCorner]
        
        switch side {
        case .left:
            if Config.leftRightLineInnerRoundedCorners {
                for maskedCorner in rightCorners {
                    hairline.layer.maskedCorners.insert(maskedCorner)
                }
            }
            if Config.leftRightLineOuterRoundedCorners {
                for maskedCorner in leftCorners {
                    hairline.layer.maskedCorners.insert(maskedCorner)
                }
            }
        case .right:
            if Config.leftRightLineInnerRoundedCorners {
                for maskedCorner in leftCorners {
                    hairline.layer.maskedCorners.insert(maskedCorner)
                }
            }
            if Config.leftRightLineOuterRoundedCorners {
                for maskedCorner in rightCorners {
                    hairline.layer.maskedCorners.insert(maskedCorner)
                }
            }
        }

        self.setContentHuggingPriority(.defaultLow, for: .horizontal)

        return hairline
    }()
    
    // - MARK: Lifecycle

    init(side: Side) {
        self.side = side
        
        super.init(frame: .zero)
        
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // - MARK: Update Functions
    
    func updateColors() {
        hairlineView.backgroundColor = .tintColor
    }
}
