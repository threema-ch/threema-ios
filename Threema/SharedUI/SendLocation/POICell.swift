//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ThreemaMacros

class POICell: ThemedCodeTableViewCell, Reusable {
    
    // MARK: - Proprties
    
    var poi: PointOfInterest? {
        didSet {
            guard let poi else {
                return
            }
            
            nameLabel.text = poi.name
            addressLabel.text = poi.address
            distanceLabel.text = localizedDistanceString(for: poi.distance)
            poiImage.image = poi.image
            updateColors()
        }
    }
    
    // MARK: Private Proprties
    
    private let accessibilityStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let nameAddressStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        return stackView
    }()
    
    private let poiImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.accessibilityElementsHidden = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let nameLabel = UILabel()
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textAlignment = .left
        nameLabel.font = UIFont.preferredFont(forTextStyle: .body)
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.numberOfLines = 0
        
        return nameLabel
    }()
    
    private let distanceLabel: UILabel = {
        let distanceLabel = UILabel()
        distanceLabel.adjustsFontForContentSizeCategory = true
        distanceLabel.font = UIFont.preferredFont(forTextStyle: .body)
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        return distanceLabel
    }()
    
    private let addressLabel: UILabel = {
        let addressLabel = UILabel()
        addressLabel.adjustsFontForContentSizeCategory = true
        addressLabel.font = UIFont.preferredFont(forTextStyle: .body)
        addressLabel.lineBreakMode = .byWordWrapping
        addressLabel.numberOfLines = 0
        
        return addressLabel
    }()
    
    private let formatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        formatter.numberFormatter.roundingMode = .up
        return formatter
    }()
    
    // MARK: - Lifecycle
    
    override func configureCell() {
        super.configureCell()
        
        // If accessibility fonts are enabled, display View differently
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            accessibilityStackView.axis = .vertical
            poiImage.isHidden = true
        }
        else {
            accessibilityStackView.alignment = .top
            accessibilityStackView.axis = .horizontal
            poiImage.isHidden = false
        }
        
        // Add Views
        nameAddressStackView.addArrangedSubview(nameLabel)
        accessibilityStackView.addArrangedSubview(nameAddressStackView)
        accessibilityStackView.addArrangedSubview(distanceLabel)
        contentView.addSubview(accessibilityStackView)
        contentView.addSubview(poiImage)
       
        let margins = contentView.layoutMarginsGuide
        let padding: CGFloat = 30
        let inset: CGFloat = 5
        
        NSLayoutConstraint.activate([
            poiImage.topAnchor.constraint(equalTo: margins.topAnchor),
            poiImage.centerXAnchor.constraint(equalTo: margins.leadingAnchor, constant: inset),
            accessibilityStackView.topAnchor.constraint(equalTo: margins.topAnchor),
            accessibilityStackView.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: padding),
            accessibilityStackView.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            accessibilityStackView.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
        ])
        
        // View
        separatorInset = UIEdgeInsets(
            top: 0,
            left: contentView.layoutMargins.left + padding / 2 + inset,
            bottom: 0,
            right: 0
        )
        updateColors()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: selected)
        updateColors()
        if selected {
            nameAddressStackView.addArrangedSubview(addressLabel)
        }
        else {
            addressLabel.removeFromSuperview()
        }
    }
        
    /// Assigns colors to the view's content
    override func updateColors() {
        super.updateColors()
        Colors.setTextColor(Colors.text, label: nameLabel)
        Colors.setTextColor(Colors.textLight, label: distanceLabel)
        Colors.setTextColor(Colors.textLight, label: addressLabel)
    }
    
    // MARK: - Functions
    
    /// Creates a localized distance String
    /// - Parameter meters: Distance in meters
    /// - Returns: Localized String describing distance
    private func localizedDistanceString(for meters: POIDistance) -> String {
        
        if !UserSettings.shared().enablePoi {
            return ""
        }
        
        if CLLocationManager().accuracyAuthorization == .reducedAccuracy {
            return ""
        }
        
        switch meters {
        case .notAvailable:
            return #localize("poi_unavailable")
        case .notSet:
            return #localize("poi_not_marked")
        case let .distance(value):
            if value <= 10 {
                return ""
            }
            let meters = Measurement(value: Double(value), unit: UnitLength.meters)
            
            return formatter.string(from: meters)
        }
    }
    
    // MARK: - Accessibility
    
    override var accessibilityLabel: String? {
        get {
            nameLabel.text ?? ""
        }
        set { }
    }
    
    override var accessibilityValue: String? {
        get {
            let distance = distanceLabel.text ?? ""
            
            return String.localizedStringWithFormat(
                #localize("poi_away"),
                distance
            )
        }
        set { }
    }
}
