import ThreemaMacros

final class StartChatAddItemCell: UITableViewCell {
    
    // MARK: - Type
    
    enum AddItemKind {
        case contact
        case group
        case distributionList
        
        var label: String {
            switch self {
            case .contact:
                #localize("contactList_add_contact")
            case .group:
                #localize("contactList_add_group")
            case .distributionList:
                #localize("distribution_list_create")
            }
        }
        
        var icon: ThreemaImageResource {
            switch self {
            case .contact:
                .systemImage("person.badge.plus")
            case .group:
                .bundleImage("threema.person.3.badge.plus")
            case .distributionList:
                .bundleImage("threema.megaphone.badge.plus")
            }
        }
        
        var enabled: Bool {
            let mdm = MDMSetup()
            return switch self {
            case .contact:
                !(mdm?.disableAddContact() ?? true)
            case .group:
                !(mdm?.disableCreateGroup() ?? false)
            case .distributionList:
                ThreemaEnvironment.distributionListsActive
            }
        }
    }
    
    // MARK: - Configure

    func configure(with kind: AddItemKind) {
        let isEnabled = kind.enabled
        var content = defaultContentConfiguration()
        content.image = kind.icon.uiImage.withConfiguration(UIImage.SymbolConfiguration(scale: .medium))
        content.text = kind.label
        content.textProperties.color = isEnabled ? .tintColor : .secondaryLabel
        content.imageProperties.tintColor = isEnabled ? .tintColor : .secondaryLabel
        
        contentConfiguration = content
        isUserInteractionEnabled = isEnabled
    }
}

// MARK: - Reusable

extension StartChatAddItemCell: Reusable { }
