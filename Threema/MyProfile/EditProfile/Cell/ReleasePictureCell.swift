import ThreemaMacros

final class ReleasePictureCell: UITableViewCell {
    
    // MARK: - Configure

    func configure(secondaryText: String, isEnabled: Bool) {
        var content = defaultContentConfiguration()
        
        content.text = #localize("edit_profile_picture_cell_title")
        content.textProperties.color = isEnabled ? .label : .secondaryLabel
        content.secondaryText = secondaryText
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
        content.prefersSideBySideTextAndSecondaryText = true
        
        contentConfiguration = content
        accessoryType = .disclosureIndicator
        isUserInteractionEnabled = isEnabled
    }
}

// MARK: - Reusable

extension ReleasePictureCell: Reusable { }
