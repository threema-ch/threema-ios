// This file is based on third party code, see below for the original author
// and original license.
// Modifications are (c) by Threema GmbH and licensed under the AGPLv3.

// Copyright (c) 2016 Pavel Pantus <pantusp@gmail.com>
// See Resources/License.html for original license

import UIKit
import ThreemaFramework

/**
 Protocol that provides default implementation for `reuseIdentifier` method.
 */
protocol PPReusableView: class {
    static var reuseIdentifier: String { get }
}

extension PPReusableView {
    static var reuseIdentifier: String {
        return NSStringFromClass(self)
    }
}

/**
 Cell with a checkmark in the bottom right corner.
 */
class PPCheckedViewCell: UICollectionViewCell {
    public let checked = UIImageView(image: StyleKit.check.withRenderingMode(.alwaysOriginal))
    public let unchecked = UIImageView(image: StyleKit.uncheck.withRenderingMode(.alwaysOriginal))

    func setupCheckmark() {
        checked.isHidden = true
        unchecked.isHidden = true
        checked.frame = CGRect.init(x: 0.0, y: 0.0, width: 22.0, height: 22.0)
        unchecked.frame = CGRect.init(x: 0.0, y: 0.0, width: 22.0, height: 22.0)
        checked.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
        unchecked.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
        addSubview(checked)
        addSubview(unchecked)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let height = checked.frame.height
        let width = checked.frame.width
        if (backgroundView != nil) {
            checked.frame = CGRect(x: backgroundView!.frame.width - (1.4 * width),
                                   y: backgroundView!.frame.height - (1.4 * height),
                                   width: width,
                                   height: height)
            unchecked.frame = CGRect(x: backgroundView!.frame.width - (1.4 * width),
                                     y: backgroundView!.frame.height - (1.4 * height),
                                     width: width,
                                     height: height)
            /***** BEGIN THREEMA MODIFICATION: accessibilityIgnoresInvertColors *********/
            self.accessibilityIgnoresInvertColors = true
            /***** END THREEMA MODIFICATION: accessibilityIgnoresInvertColors *********/
        }
    }

    public func set(selected: Bool) {
        checked.isHidden = !selected
        unchecked.isHidden = selected
    }
}

extension PPCheckedViewCell: PPReusableView {}
