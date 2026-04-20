import ThreemaMacros

enum CreateEditGroupDistributionListDisplayMode {
    
    case group(GroupAction)
    case distributionList(DistributionListAction)

    enum GroupAction {
        case create(data: EditData)
        case edit(group: Group)
        case clone(group: Group, data: EditData)
    }

    enum DistributionListAction {
        case create(data: EditData)
        case edit(list: DistributionList)
    }
}

// MARK: - Helpers

extension CreateEditGroupDistributionListDisplayMode {
    var isEdit: Bool {
        switch self {
        case .group(.edit), .distributionList(.edit):
            true
        default:
            false
        }
    }
    
    var isGroup: Bool {
        switch self {
        case .group:
            true
        default:
            false
        }
    }
    
    var editedGroup: Group? {
        switch self {
        case let .group(.edit(group)):
            group
        case let .group(.clone(group, _)):
            group
        default:
            nil
        }
    }

    var editedDistributionList: DistributionList? {
        if case let .distributionList(.edit(content)) = self {
            return content
        }
        return nil
    }
    
    var profilePictureType: ProfilePictureGenerator.ProfilePictureType {
        switch self {
        case .group:
            .group
        case .distributionList:
            .distributionList
        }
    }
    
    var conversationType: EditProfilePictureView.ConversationType {
        switch self {
        case .group:
            .group
        case .distributionList:
            .distributionList
        }
    }
    
    var title: String {
        switch (self, isEdit) {
        case (.group, true): #localize("edit_group_title")
        case (.group, false): #localize("create")
        case (.distributionList, true): #localize("distribution_list_edit")
        case (.distributionList, false): #localize("distribution_list_create")
        }
    }
    
    var usesNonGeneratedProfilePicture: Bool? {
        editedGroup?.usesNonGeneratedProfilePicture ?? editedDistributionList?.usesNonGeneratedProfilePicture
    }
    
    var profilePicture: UIImage? {
        switch self {
        case .group:
            editedGroup?.profilePicture ?? ProfilePictureGenerator.unknownGroupImage
        case .distributionList:
            editedDistributionList?.profilePicture ?? ProfilePictureGenerator.unknownDistributionListImage
        }
    }
    
    func generateProfilePicture() -> UIImage? {
        editedGroup?.generatedProfilePicture() ?? editedDistributionList?.generatedProfilePicture()
    }
    
    var countLabelKind: RecipientCollectionCountLabel.Kind {
        switch self {
        case .group:
            .group
        case .distributionList:
            .distributionList
        }
    }
}
