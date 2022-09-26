//
//  MaterialShowcase.swift
//  MaterialShowcase
//
//  Created by Quang Nguyen on 5/4/17.
//  Copyright © 2017 Aromajoin. All rights reserved.
//
import UIKit

@objc public protocol MaterialShowcaseDelegate: class {
  @objc optional func showCaseWillDismiss(showcase: MaterialShowcase, didTapTarget:Bool)
  @objc optional func showCaseDidDismiss(showcase: MaterialShowcase, didTapTarget:Bool)
}

open class MaterialShowcase: UIView {
  
  @objc public enum BackgroundTypeStyle: Int {
    case circle //default
    case full//full screen
  }
  
  // MARK: Material design guideline constant
  let BACKGROUND_PROMPT_ALPHA: CGFloat = 0.96
  let TARGET_HOLDER_RADIUS: CGFloat = 44
  let TEXT_CENTER_OFFSET: CGFloat = 44 + 20
  let INSTRUCTIONS_CENTER_OFFSET: CGFloat = 20
  let LABEL_MARGIN: CGFloat = 40
  let TARGET_PADDING: CGFloat = 20
  
  // Other default properties
  let LABEL_DEFAULT_HEIGHT: CGFloat = 50
  let BACKGROUND_DEFAULT_COLOR = UIColor.fromHex(hexString: "#2196F3")
  let TARGET_HOLDER_COLOR = UIColor.white
  
  // MARK: Animation properties
  var ANI_COMEIN_DURATION: TimeInterval = 0.5 // second
  var ANI_GOOUT_DURATION: TimeInterval = 0.5  // second
  var ANI_TARGET_HOLDER_SCALE: CGFloat = 2.2
  let ANI_RIPPLE_COLOR = UIColor.white
  let ANI_RIPPLE_ALPHA: CGFloat = 0.5
  let ANI_RIPPLE_SCALE: CGFloat = 1.6
  
  var offsetThreshold: CGFloat = 88
  
  // MARK: Private view properties
  var closeButton : UIButton!
  
  var containerView: UIView!
  var targetView: UIView!
  var backgroundView: UIView!
  var targetHolderView: UIView!
  var hiddenTargetHolderView: UIView!
  var targetRippleView: UIView!
  var targetCopyView: UIView!
  var instructionView: MaterialShowcaseInstructionView!
  
  
  public var skipButton: (() -> Void)?
  var onTapThrough: (() -> Void)?
  
  // MARK: Public Properties
  // setSkipImage
  public var skipImage = "HintClose"
  
  // Background
  @objc public var backgroundAlpha: CGFloat = 1.0
  @objc public var backgroundPromptColor: UIColor!
  @objc public var backgroundPromptColorAlpha: CGFloat = 0.0
  @objc public var backgroundViewType: BackgroundTypeStyle = .circle
  @objc public var backgroundRadius: CGFloat = -1.0 // If the value is negative, calculate the radius automatically
  // Tap zone settings
  // - false: recognize tap from all displayed showcase.
  // - true: recognize tap for targetView area only.
  @objc public var isTapRecognizerForTargetView: Bool = false
  // Target
  @objc public var shouldSetTintColor: Bool = true
  @objc public var targetTintColor: UIColor!
  @objc public var targetHolderRadius: CGFloat = 0.0
  @objc public var targetHolderColor: UIColor!
  // Text
  @objc public var primaryText: String!
  @objc public var secondaryText: String!
  @objc public var primaryTextColor: UIColor!
  @objc public var secondaryTextColor: UIColor!
  @objc public var primaryTextSize: CGFloat = 0.0
  @objc public var secondaryTextSize: CGFloat = 0.0
  @objc public var primaryTextFont: UIFont?
  @objc public var secondaryTextFont: UIFont?
  @objc public var primaryTextAlignment: NSTextAlignment = .left
  @objc public var secondaryTextAlignment: NSTextAlignment = .left
  // Animation
  @objc public var aniComeInDuration: TimeInterval = 0.0
  @objc public var aniGoOutDuration: TimeInterval = 0.0
  @objc public var aniRippleScale: CGFloat = 0.0
  @objc public var aniRippleColor: UIColor!
  @objc public var aniRippleAlpha: CGFloat = 0.0
  // Delegate
  @objc public weak var delegate: MaterialShowcaseDelegate?
  
  public init() {
    // Create frame
    let frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    super.init(frame: frame)
    
    configure()
  }
  
  // No supported initilization method
  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - Public APIs
extension MaterialShowcase {
  
  /// Sets a general UIView as target
  @objc public func setTargetView(view: UIView) {
    targetView = view
    if let label = targetView as? UILabel {
      targetTintColor = label.textColor
      backgroundPromptColor = label.textColor
    } else if let button = targetView as? UIButton {
      let tintColor = button.titleColor(for: .normal)
      targetTintColor = tintColor
      backgroundPromptColor = tintColor
    } else {
      targetTintColor = targetView.tintColor
      backgroundPromptColor = targetView.tintColor
    }
  }
  
  /// Sets a UIBarButtonItem as target
  @objc public func setTargetView(button: UIButton, tapThrough: Bool = false) {
    targetView = button
    let tintColor = button.titleColor(for: .normal)
    targetTintColor = tintColor
    backgroundPromptColor = tintColor
    if tapThrough {
      onTapThrough = { button.sendActions(for: .touchUpInside)  }
    }
  }
  
  /// Sets a UIBarButtonItem as target
  @objc public func setTargetView(barButtonItem: UIBarButtonItem, tapThrough: Bool = false) {
    if let view = (barButtonItem.value(forKey: "view") as? UIView)?.subviews.first {
      targetView = view
      if tapThrough {
        onTapThrough = { _ = barButtonItem.target?.perform(barButtonItem.action, with: nil) }
      }
    }
  }
  
  /// Sets a UITabBar Item as target
  @objc public func setTargetView(tabBar: UITabBar, itemIndex: Int, tapThrough: Bool = false) {
    let tabBarItems = orderedTabBarItemViews(of: tabBar)
    if itemIndex < tabBarItems.count {
      targetView = tabBarItems[itemIndex]
      targetTintColor = tabBar.tintColor
      backgroundPromptColor = tabBar.tintColor
      if tapThrough {
        onTapThrough = { tabBar.selectedItem = tabBar.items?[itemIndex] }
      }
    } else {
      print ("The tab bar item index is out of range")
    }
  }
  
  /// Sets a UITableViewCell as target
  @objc public func setTargetView(tableView: UITableView, section: Int, row: Int) {
    let indexPath = IndexPath(row: row, section: section)
    targetView = tableView.cellForRow(at: indexPath)?.contentView
    // for table viewcell, we do not need target holder (circle view)
    // therefore, set its radius = 0
    targetHolderRadius = 0
  }
  
  
  /// Sets a UICollectionViewCell as target
  @objc public func setTargetView(collectionView: UICollectionView, section: Int, item: Int) {
    let indexPath = IndexPath(item: item, section: section)
    targetView = collectionView.cellForItem(at: indexPath)
    // for table viewcell, we do not need target holder (circle view)
    // therefore, set its radius = 0
    targetHolderRadius = 0
  }
  
  @objc func dismissTutorialButtonDidTouch() {
    skipButton?()
  }
  
  /// Shows it over current screen after completing setup process
  @objc public func show(animated: Bool = true,hasShadow: Bool = true, hasSkipButton: Bool = true, completion handler: (()-> Void)?) {
    initViews()
    alpha = 0.0
    containerView.addSubview(self)
    layoutIfNeeded()
    
    let scale = TARGET_HOLDER_RADIUS / (backgroundView.frame.width / 2)
    let center = backgroundView.center
    
    backgroundView.transform = CGAffineTransform(scaleX: scale, y: scale) // Initial set to support animation
    backgroundView.center = targetHolderView.center
    
    
    
    
    
    if hasSkipButton {
      
      closeButton = UIButton()
      
      closeButton.setImage(UIImage(named: skipImage), for: .normal)
      addSubview(closeButton)
      closeButton.addTarget(self, action: #selector(dismissTutorialButtonDidTouch), for: .touchUpInside)
      
      let margins = layoutMarginsGuide
      closeButton.translatesAutoresizingMaskIntoConstraints = false
      closeButton.topAnchor.constraint(equalTo: margins.topAnchor, constant: 0).isActive = true
      closeButton.rightAnchor.constraint(equalTo: margins.rightAnchor, constant: -8).isActive = true
      closeButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.13).isActive = true
      closeButton.heightAnchor.constraint(equalTo: closeButton.widthAnchor, multiplier: 1.0/1.0).isActive = true
    }

    
    if hasShadow {
      backgroundView.layer.shadowColor = UIColor.black.cgColor
      backgroundView.layer.shadowRadius = 5.0
      backgroundView.layer.shadowOpacity = 0.5
      backgroundView.layer.shadowOffset = .zero
      backgroundView.clipsToBounds = false
    }
    
    if animated {
      UIView.animate(withDuration: aniComeInDuration, animations: {
        self.targetHolderView.transform = CGAffineTransform(scaleX: 1, y: 1)
        self.backgroundView.transform = CGAffineTransform(scaleX: 1, y: 1)
        self.backgroundView.center = center
        self.alpha = self.backgroundAlpha
      }, completion: { _ in
        self.startAnimations()
      })
    } else {
      alpha = backgroundAlpha
    }
    // Handler user's action after showing.
    handler?()
  }
  
}

// MARK: - Utility API
extension MaterialShowcase {
  /// Returns the current showcases displayed on screen.
  /// It will return null if no showcase exists.
  public static func presentedShowcases() -> [MaterialShowcase]? {
      /***** BEGIN THREEMA MODIFICATION: Use windows instead of keyWindow *********/
      guard let window = UIApplication.shared.windows.first else {
      /***** END THREEMA MODIFICATION: Use windows instead of keyWindow *********/
      return nil
    }
    return window.subviews.filter({ (view) -> Bool in
      return view is MaterialShowcase
    }) as? [MaterialShowcase]
  }
}

// MARK: - Setup views internally
extension MaterialShowcase {
  
  /// Initializes default view properties
  func configure() {
    backgroundColor = UIColor.clear
      /***** BEGIN THREEMA MODIFICATION: Use windows instead of keyWindow *********/
      guard let window = UIApplication.shared.windows.first else {
      /***** END THREEMA MODIFICATION: Use windows instead of keyWindow *********/
      return
    }
    containerView = window
    setDefaultProperties()
  }
  
  func setDefaultProperties() {
    // Background
    backgroundPromptColor = BACKGROUND_DEFAULT_COLOR
    backgroundPromptColorAlpha = BACKGROUND_PROMPT_ALPHA
    // Target view
    targetTintColor = BACKGROUND_DEFAULT_COLOR
    targetHolderColor = TARGET_HOLDER_COLOR
    targetHolderRadius = TARGET_HOLDER_RADIUS
    // Text
    primaryText = MaterialShowcaseInstructionView.PRIMARY_DEFAULT_TEXT
    secondaryText = MaterialShowcaseInstructionView.SECONDARY_DEFAULT_TEXT
    primaryTextColor = MaterialShowcaseInstructionView.PRIMARY_TEXT_COLOR
    secondaryTextColor = MaterialShowcaseInstructionView.SECONDARY_TEXT_COLOR
    primaryTextSize = MaterialShowcaseInstructionView.PRIMARY_TEXT_SIZE
    secondaryTextSize = MaterialShowcaseInstructionView.SECONDARY_TEXT_SIZE
    // Animation
    aniComeInDuration = ANI_COMEIN_DURATION
    aniGoOutDuration = ANI_GOOUT_DURATION
    aniRippleAlpha = ANI_RIPPLE_ALPHA
    aniRippleColor = ANI_RIPPLE_COLOR
    aniRippleScale = ANI_RIPPLE_SCALE
  }
  
  func startAnimations() {
    let options: UIView.KeyframeAnimationOptions = [.curveEaseInOut, .repeat]
    UIView.animateKeyframes(withDuration: 1, delay: 0, options: options, animations: {
      UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5, animations: {
        self.targetRippleView.alpha = self.ANI_RIPPLE_ALPHA
        self.targetHolderView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        self.targetRippleView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
      })
      
      UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5, animations: {
        self.targetHolderView.transform = CGAffineTransform.identity
        self.targetRippleView.alpha = 0
        self.targetRippleView.transform = CGAffineTransform(scaleX: self.aniRippleScale, y: self.aniRippleScale)
      })
      
    }, completion: nil)
  }
  
  func initViews() {
    let center = calculateCenter(at: targetView, to: containerView)
    
    addTargetRipple(at: center)
    addTargetHolder(at: center)
    
    // if color is not UIColor.clear, then add the target snapshot
    if targetHolderColor != .clear {
      addTarget(at: center)
    }
    
    //In iPad version InstructionView was add to backgroundView
    if UIDevice.current.userInterfaceIdiom == .pad {
      addBackground()
    }
    
    addInstructionView(at: center)
    instructionView.layoutIfNeeded()
    
    //In iPhone version InstructionView was add to self view
    if UIDevice.current.userInterfaceIdiom != .pad {
      addBackground()
    }
    
    // Disable subview interaction to let users click to general view only
    subviews.forEach({$0.isUserInteractionEnabled = false})
    
    if isTapRecognizerForTargetView {
      //Add gesture recognizer for targetCopyView
      hiddenTargetHolderView.addGestureRecognizer(tapGestureRecoganizer())
      hiddenTargetHolderView.isUserInteractionEnabled = true
    } else {
      // Add gesture recognizer for both container and its subview
      addGestureRecognizer(tapGestureRecoganizer())
      hiddenTargetHolderView.addGestureRecognizer(tapGestureRecoganizer())
      hiddenTargetHolderView.isUserInteractionEnabled = true
    }
  }
  
  /// Add background which is a big circle
  private func addBackground() {
    switch self.backgroundViewType {
    case .circle:
      let radius: CGFloat
      
      if backgroundRadius < 0 {
        radius = getDefaultBackgroundRadius()
      } else {
        radius = backgroundRadius
      }
      
      let center = targetRippleView.center
      backgroundView = UIView(frame: CGRect(x: 0, y: 0, width: radius * 2,height: radius * 2))
      backgroundView.center = center
      backgroundView.asCircle()
      
      
      
    case .full:
      backgroundView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width,height: UIScreen.main.bounds.height))
    }
    
    
    backgroundView.backgroundColor = backgroundPromptColor.withAlphaComponent(backgroundPromptColorAlpha)
    insertSubview(backgroundView, belowSubview: targetRippleView)
    
//    addBackgroundMask(with: targetHolderRadius, in: backgroundView)
  }
  
  private func getDefaultBackgroundRadius() -> CGFloat {
    var radius: CGFloat = 0.0
    if UIDevice.current.userInterfaceIdiom == .pad {
      radius = 300.0
    } else {
      radius = getOuterCircleRadius(center: center, textBounds: instructionView.frame, targetBounds: targetRippleView.frame)
    }
    return radius
  }
  
  private func addBackgroundMask(with radius: CGFloat, in view: UIView) {
    let center = backgroundViewType == .circle ? view.bounds.center : targetRippleView.center
  
    let mutablePath = CGMutablePath()
    mutablePath.addRect(view.bounds)
    mutablePath.addArc(center: center, radius: radius, startAngle: 0.0, endAngle: 2 * .pi, clockwise: false)
    
    let mask = CAShapeLayer()
    mask.path = mutablePath
    mask.fillRule = CAShapeLayerFillRule.evenOdd
    
    view.layer.mask = mask
  }
  
  /// A background view which add ripple animation when showing target view
  private func addTargetRipple(at center: CGPoint) {
    targetRippleView = UIView(frame: CGRect(x: 0, y: 0, width: targetHolderRadius * 2,height: targetHolderRadius * 2))
    targetRippleView.center = center
    targetRippleView.backgroundColor = aniRippleColor
    targetRippleView.alpha = 0.0 //set it invisible
    targetRippleView.asCircle()
    addSubview(targetRippleView)
  }
  
  /// A circle-shape background view of target view
  private func addTargetHolder(at center: CGPoint) {
    hiddenTargetHolderView = UIView()
    hiddenTargetHolderView.backgroundColor = .clear
    targetHolderView = UIView(frame: CGRect(x: 0, y: 0, width: targetHolderRadius * 2,height: targetHolderRadius * 2))
    targetHolderView.center = center
    targetHolderView.backgroundColor = targetHolderColor
    targetHolderView.asCircle()
    hiddenTargetHolderView.frame = targetHolderView.frame
    targetHolderView.transform = CGAffineTransform(scaleX: 1/ANI_TARGET_HOLDER_SCALE, y: 1/ANI_TARGET_HOLDER_SCALE) // Initial set to support animation
    addSubview(hiddenTargetHolderView)
    addSubview(targetHolderView)
  }
  
  /// Create a copy view of target view
  /// It helps us not to affect the original target view
  private func addTarget(at center: CGPoint) {
    targetCopyView = targetView.snapshotView(afterScreenUpdates: true)
    
    if shouldSetTintColor {
      targetCopyView.setTintColor(targetTintColor, recursive: true)
      
      if targetCopyView is UIButton {
        let button = targetView as! UIButton
        let buttonCopy = targetCopyView as! UIButton
        buttonCopy.setImage(button.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
        buttonCopy.setTitleColor(targetTintColor, for: .normal)
        buttonCopy.isEnabled = true
      } else if targetCopyView is UIImageView {
        let imageView = targetView as! UIImageView
        let imageViewCopy = targetCopyView as! UIImageView
        imageViewCopy.image = imageView.image?.withRenderingMode(.alwaysTemplate)
      } else if let imageViewCopy = targetCopyView.subviews.first as? UIImageView,
        let labelCopy = targetCopyView.subviews.last as? UILabel {
        let imageView = targetView.subviews.first as! UIImageView
        imageViewCopy.image = imageView.image?.withRenderingMode(.alwaysTemplate)
        labelCopy.textColor = targetTintColor
      } else if let label = targetCopyView as? UILabel {
        label.textColor = targetTintColor
      }
    }
    
    let width = targetCopyView.frame.width
    let height = targetCopyView.frame.height
    targetCopyView.frame = CGRect(x: 0, y: 0, width: width, height: height)
    targetCopyView.center = center
    targetCopyView.translatesAutoresizingMaskIntoConstraints = true
    
    addSubview(targetCopyView)
  }
  
  /// Configures and adds primary label view
  private func addInstructionView(at center: CGPoint) {
    instructionView = MaterialShowcaseInstructionView()
    
    instructionView.primaryTextAlignment = primaryTextAlignment
    instructionView.primaryTextFont = primaryTextFont
    instructionView.primaryTextSize = primaryTextSize
    instructionView.primaryTextColor = primaryTextColor
    instructionView.primaryText = primaryText
    
    instructionView.secondaryTextAlignment = secondaryTextAlignment
    instructionView.secondaryTextFont = secondaryTextFont
    instructionView.secondaryTextSize = secondaryTextSize
    instructionView.secondaryTextColor = secondaryTextColor
    instructionView.secondaryText = secondaryText
    
    // Calculate x position
    var xPosition = LABEL_MARGIN
    
    // Calculate y position
    var yPosition: CGFloat!
    
    // Calculate instructionView width
    var width : CGFloat
    
    if UIDevice.current.userInterfaceIdiom == .pad {
      width = backgroundView.frame.width - xPosition
      
      if backgroundView.frame.origin.x < 0 {
        xPosition = abs(backgroundView.frame.origin.x) + xPosition
      } else if (backgroundView.frame.origin.x + backgroundView.frame.size.width >
        UIScreen.main.bounds.width) {
        width = backgroundView.frame.size.width - (xPosition*2)
      }
      if xPosition + width > backgroundView.frame.size.width {
        width = width - CGFloat(xPosition/2)
      }
      
      if getTargetPosition(target: targetView, container: containerView) == .above {
        yPosition = (backgroundView.frame.size.height/2) + TEXT_CENTER_OFFSET
      } else {
        yPosition = TEXT_CENTER_OFFSET + LABEL_DEFAULT_HEIGHT * 2
      }
    } else {
      if getTargetPosition(target: targetView, container: containerView) == .above {
        yPosition = center.y + TARGET_PADDING +  (targetView.bounds.height / 2 > targetHolderRadius ? targetView.bounds.height / 2 : targetHolderRadius)
      } else {
        yPosition = center.y - TEXT_CENTER_OFFSET - LABEL_DEFAULT_HEIGHT * 2
      }
      
      width = containerView.frame.width - (xPosition + xPosition)
    }
    
    instructionView.frame = CGRect(x: xPosition,
                                   y: yPosition,
                                   width: width ,
                                   height: 0)
    if UIDevice.current.userInterfaceIdiom == .pad {
      backgroundView.addSubview(instructionView)
    } else {
      addSubview(instructionView)
    }
  }
  
  /// Handles user's tap
  private func tapGestureRecoganizer() -> UIGestureRecognizer {
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(MaterialShowcase.tapGestureSelector))
    tapGesture.numberOfTapsRequired = 1
    tapGesture.numberOfTouchesRequired = 1
    return tapGesture
  }
  
  @objc private func tapGestureSelector(tapGesture:UITapGestureRecognizer) {
    completeShowcase(didTapTarget: tapGesture.view === hiddenTargetHolderView)
  }
  
  /// Default action when dimissing showcase
  /// Notifies delegate, removes views, and handles out-going animation
  @objc public func completeShowcase(animated: Bool = true, didTapTarget: Bool = false) {
    if delegate != nil && delegate?.showCaseDidDismiss != nil {
      delegate?.showCaseWillDismiss?(showcase: self, didTapTarget: didTapTarget)
    }
    if animated {
      targetRippleView.removeFromSuperview()
      UIView.animateKeyframes(withDuration: aniGoOutDuration, delay: 0, options: [.calculationModeLinear], animations: {
        UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 3/5, animations: {
          self.targetHolderView.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
          self.backgroundView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
          self.backgroundView.alpha = 0
        })
        UIView.addKeyframe(withRelativeStartTime: 3/5, relativeDuration: 2/5, animations: {
          self.alpha = 0
        })
      }, completion: { (success) in
        // Recycle subviews
        self.recycleSubviews()
        // Remove it from current screen
        self.removeFromSuperview()
      })
    } else {
      // Recycle subviews
      self.recycleSubviews()
      // Remove it from current screen
      self.removeFromSuperview()
    }
    if delegate != nil && delegate?.showCaseDidDismiss != nil {
      delegate?.showCaseDidDismiss?(showcase: self, didTapTarget: didTapTarget)
    }
    
    if didTapTarget {
      onTapThrough?()
    }
  }
  
  private func recycleSubviews() {
    subviews.forEach({$0.removeFromSuperview()})
  }
}

// MARK: - Private helper methods
extension MaterialShowcase {
  
  /// Defines the position of target view
  /// which helps to place texts at suitable positions
  enum TargetPosition {
    case above // at upper screen part
    case below // at lower screen part
  }
  
  /// Detects the position of target view relative to its container
  func getTargetPosition(target: UIView, container: UIView) -> TargetPosition {
    let center = calculateCenter(at: targetView, to: container)
    if center.y < container.frame.height / 2 {
      return .above
    } else {
      return .below
    }
  }
  
  
  
  // Calculates the center point based on targetview
  func calculateCenter(at targetView: UIView, to containerView: UIView) -> CGPoint {
    let targetRect = targetView.convert(targetView.bounds , to: containerView)
    return targetRect.center
    
  }
  
  // Gets all UIView from TabBarItem.
  func orderedTabBarItemViews(of tabBar: UITabBar) -> [UIView] {
    let interactionViews = tabBar.subviews.filter({$0.isUserInteractionEnabled})
    return interactionViews.sorted(by: {$0.frame.minX < $1.frame.minX})
  }
}
