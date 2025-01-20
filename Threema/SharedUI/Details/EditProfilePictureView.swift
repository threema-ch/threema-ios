//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

import ThreemaMacros
import UIKit

// MARK: - EditProfilePictureView.Configuration

extension EditProfilePictureView {
    private struct Configuration: DetailsConfiguration {
        /// Spacing between buttons at the bottom
        let buttonSpacing: CGFloat = 16
        
        /// Spacing between profile picture and buttons
        let verticalSpacing: CGFloat = 8
        
        let bottomSpacing: CGFloat = 16
        
        let profilePictureJPEGCompressionQuality: CGFloat = 0.7
    }
}

/// Show and change a provided profile picture
///
/// Changes are reported to the provided closure which needs to take care of storing the new image.
///
/// Changes are only possible if editing is allowed through the initializer.
/// You tell if the image is a default (and cannot be deleted) through the initializer and callback closure.
class EditProfilePictureView: UIStackView {
    
    /// Closure called on every image change
    /// - Parameter newJPEGImageData: Cropped and resized JPEG image data of new chosen profile picture.
    ///                               `nil` if image was deleted.
    /// - Returns: An image for the new profile picture and if it is a default image (thus cannot be deleted)
    typealias ImageUpdated = (_ newJPEGImageData: Data?) -> (newProfilePicture: UIImage?, isDefaultImage: Bool)
    
    enum ConversationType {
        case contact, group, distributionList
    }
    
    // MARK: - Private properties
    
    /// View controller used to present the pickers on
    private weak var presentingViewController: UIViewController?
    
    /// Temp anchor for popovers with picker & cropper views
    private var presentingRect: CGRect = .zero
    
    private let conversationType: ConversationType
    
    private var profilePicture: UIImage? {
        didSet {
            guard profilePicture != oldValue else {
                return
            }
            updateProfileImageView()
        }
    }
    
    private let isEditable: Bool
    private var isDefaultImage: Bool {
        didSet {
            guard isDefaultImage != oldValue else {
                return
            }
            
            updateDeleteButton()
        }
    }
    
    private lazy var deleteAction: ThemedCodeButton.Action = { [weak self] _ in
        guard let strongSelf = self else {
            return
        }
        
        (strongSelf.profilePicture, strongSelf.isDefaultImage) = strongSelf.imageUpdated(nil)
    }
    
    private let imageUpdated: ImageUpdated
    
    private static let configuration = Configuration()
    
    // MARK: Subviews & layout
    
    private lazy var deleteButtonConstraints: [NSLayoutConstraint] = [
        deleteButton.topAnchor.constraint(equalTo: profilePictureView.topAnchor),
        deleteButton.trailingAnchor.constraint(equalTo: profilePictureView.trailingAnchor),
    ]

    private lazy var deleteButton = OpaqueDeleteButton(action: deleteAction)
    
    private lazy var profilePictureView: ProfilePictureImageView = {
        let profilePictureView = ProfilePictureImageView()
        profilePictureView.heightAnchor
            .constraint(equalToConstant: EditProfilePictureView.configuration.profilePictureSize).isActive = true
        
        profilePictureView.translatesAutoresizingMaskIntoConstraints = false
        return profilePictureView
    }()
    
    private lazy var takePictureButton = CircleButton(
        sfSymbolName: "camera",
        accessibilityLabel: #localize("take_photo")
    ) { [weak self] button in
        self?.showImagePicker(for: .camera, in: button)
    }
    
    private lazy var choosePictureButton = CircleButton(
        sfSymbolName: "photo.on.rectangle",
        accessibilityLabel: #localize("choose_existing_photo")
    ) { [weak self] button in
        self?.showImagePicker(for: .photoLibrary, in: button)
    }
    
    private lazy var buttonStack: UIStackView = {
        let stackView = UIStackView()
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            stackView.addArrangedSubview(takePictureButton)
        }
        
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            stackView.addArrangedSubview(choosePictureButton)
        }
        
        stackView.axis = .horizontal
        stackView.spacing = EditProfilePictureView.configuration.buttonSpacing
        stackView.distribution = .equalSpacing
        
        return stackView
    }()
    
    // MARK: Accessibility actions
    
    // This should be in sync with the button stack
    private lazy var accessibilityDefaultActions: [UIAccessibilityCustomAction] = {
        var actions = [UIAccessibilityCustomAction]()
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            actions.append(UIAccessibilityCustomAction(
                name: #localize("take_photo"),
                target: self,
                selector: #selector(accessibilityShowCameraPicker)
            ))
        }
        
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            actions.append(UIAccessibilityCustomAction(
                name: #localize("choose_existing_photo"),
                target: self,
                selector: #selector(accessibilityShowLibraryPicker)
            ))
        }
        
        return actions
    }()
    
    private lazy var accessibilityDeleteAction = UIAccessibilityCustomAction(
        name: #localize("delete"),
        target: self,
        selector: #selector(accessibilityDeleteProfilePicture)
    )
    
    // MARK: - Lifecycle
    
    /// Create a new view to edit the provided profile picture
    ///
    /// - Parameters:
    ///   - viewController: View controller to present the pickers on
    ///   - profilePicture: Profile picture to show initially
    ///   - isDefaultImage: Is the provided image a default, that cannot be deleted
    ///   - isEditable:     Can the profile picture actually be changed (including deletion)
    ///   - imageUpdated:   Closure called on every profile picture image change
    init(
        in viewController: UIViewController,
        profilePicture: UIImage?,
        isDefaultImage: Bool,
        isEditable: Bool = true,
        conversationType: ConversationType,
        imageUpdated: @escaping ImageUpdated
    ) {
        
        self.presentingViewController = viewController
        self.profilePicture = profilePicture
        self.isEditable = isEditable
        self.isDefaultImage = isDefaultImage
        self.imageUpdated = imageUpdated
        self.conversationType = conversationType
        
        super.init(frame: .zero)
        
        configureStack()
        updateProfileImageView()
        updateDeleteButton()
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configure
    
    private func configureStack() {
        // We initially hide the delete button to get a consistent state
        deleteButton.isHidden = true
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        
        profilePictureView.addSubview(deleteButton)
        addArrangedSubview(profilePictureView)

        if isEditable {
            addArrangedSubview(buttonStack)
        }
        
        axis = .vertical
        alignment = .center
        spacing = EditProfilePictureView.configuration.verticalSpacing
        
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: 0,
            bottom: EditProfilePictureView.configuration.bottomSpacing,
            trailing: 0
        )
        isLayoutMarginsRelativeArrangement = true
        
        isAccessibilityElement = true
        
        if isEditable {
            accessibilityLabel = #localize("edit_avatar_edit_picture_accessibility_label")
        }
        else {
            accessibilityLabel = #localize("edit_avatar_picture_accessibility_label")
            accessibilityValue = #localize("edit_avatar_picture_not_editable_accessibility")
        }
    }
    
    // MARK: - Update
    
    private func updateProfileImageView() {
        guard let profilePicture else {
            switch conversationType {
            case .contact:
                profilePictureView.info = .edit(ProfilePictureGenerator.unknownContactImage)
            case .group:
                profilePictureView.info = .edit(ProfilePictureGenerator.unknownGroupImage)
            case .distributionList:
                profilePictureView.info = .edit(ProfilePictureGenerator.unknownDistributionListImage)
            }
            return
        }
        
        profilePictureView.info = .edit(profilePicture)
    }
    
    private func updateDeleteButton() {
        guard isEditable else {
            hideDeleteButton()
            return
        }
        
        if isDefaultImage {
            hideDeleteButton()
        }
        else {
            showDeleteButton()
        }
    }
    
    // MARK: Update helper
    
    private func hideDeleteButton() {
        guard !deleteButton.isHidden else {
            return
        }
        
        deleteButton.isHidden = true
        NSLayoutConstraint.deactivate(deleteButtonConstraints)
    }
    
    private func showDeleteButton() {
        guard deleteButton.isHidden else {
            return
        }
        
        deleteButton.isHidden = false
        NSLayoutConstraint.activate(deleteButtonConstraints)
    }
    
    // MARK: - Show picker helper
    
    private func showImagePicker(for sourceType: UIImagePickerController.SourceType, in view: UIView?) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = sourceType
        imagePickerController.mediaTypes = [UTType.image.identifier]
        
        // Quite a hack. Maybe generalize that in modal presenter?
        
        presentingRect = .zero
        if let presentingViewController,
           let view {
            presentingRect = presentingViewController.view.convert(
                view.frame,
                from: view.superview
            )
        }
        
        ModalPresenter.present(
            imagePickerController,
            on: presentingViewController,
            from: presentingRect,
            in: presentingViewController?.view
        )
    }
    
    // MARK: - Accessibility
    
    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            guard isEditable else {
                // No actions should be available if we cannot edit the profile picture
                return nil
            }
            
            var actions = accessibilityDefaultActions
            
            // Only add delete action if the button is also shown
            if !deleteButton.isHidden {
                actions.append(accessibilityDeleteAction)
            }
            
            return actions
        }
        set { }
    }
    
    // Helper for accessibility actions
    
    @objc private func accessibilityShowCameraPicker() -> Bool {
        showImagePicker(for: .camera, in: self)
        return true
    }
    
    @objc private func accessibilityShowLibraryPicker() -> Bool {
        showImagePicker(for: .photoLibrary, in: self)
        return true
    }
    
    @objc private func accessibilityDeleteProfilePicture() -> Bool {
        deleteAction(deleteButton)
        return true
    }
}

// MARK: - UINavigationControllerDelegate, UIImagePickerControllerDelegate

extension EditProfilePictureView: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        
        guard let selectedImage = info[.originalImage] as? UIImage else {
            picker.dismiss(animated: true)
            
            if let presentingViewController {
                UIAlertTemplate.showAlert(
                    owner: presentingViewController,
                    title: #localize("edit_avatar_no_image_found_title"),
                    message: #localize("edit_avatar_no_image_found_message")
                )
            }
            
            return
        }
        
        let imageCropViewController = RSKImageCropViewController(image: selectedImage, cropMode: .circle)
        imageCropViewController.delegate = self
        imageCropViewController.avoidEmptySpaceAroundImage = true
        // Make crop picker the appropriate size on an iPad
        imageCropViewController.preferredContentSize = CGSize(
            width: Int(kContactImageSize),
            height: Int(kContactImageSize)
        )
        
        picker.dismiss(animated: true)
        
        ModalPresenter.present(
            imageCropViewController,
            on: presentingViewController,
            from: presentingRect,
            in: presentingViewController?.view
        )
    }
}

// MARK: - RSKImageCropViewControllerDelegate

extension EditProfilePictureView: RSKImageCropViewControllerDelegate {
    func imageCropViewController(
        _ controller: RSKImageCropViewController,
        didCropImage croppedImage: UIImage,
        usingCropRect cropRect: CGRect,
        rotationAngle: CGFloat
    ) {
    
        let scaledImage = MediaConverter.scale(croppedImage, toMaxSize: CGFloat(kContactImageSize))
        let jpegImageData = scaledImage?
            .jpegData(compressionQuality: EditProfilePictureView.configuration.profilePictureJPEGCompressionQuality)
        
        (profilePicture, isDefaultImage) = imageUpdated(jpegImageData)
        
        controller.dismiss(animated: true)
    }

    func imageCropViewControllerDidCancelCrop(_ controller: RSKImageCropViewController) {
        controller.dismiss(animated: true)
    }
}
