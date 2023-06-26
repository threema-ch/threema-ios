//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

import UIKit

// MARK: - EditAvatarView.Configuration

extension EditAvatarView {
    private struct Configuration: DetailsConfiguration {
        /// Spacing between buttons at the bottom
        let buttonSpacing: CGFloat = 16
        
        /// Spacing between avatar image and buttons
        let verticalSpacing: CGFloat = 8
        
        let bottomSpacing: CGFloat = 16
        
        let avatarJPEGCompressionQuality: CGFloat = 0.7
    }
}

extension EditAvatarView {
    /// The expected avatar size to provide during initialization and on closure calls
    static var avatarImageSize: CGFloat {
        EditAvatarView.configuration.avatarSize
    }
}

/// Show and change a provided avatar
///
/// Changes are reported to the provided closure which needs to take care of storing the new image.
///
/// Changes are only possible if editing is allowed through the initializer.
/// You tell if the image is a default (and cannot be deleted) through the initializer and callback closure.
class EditAvatarView: UIStackView {
    
    /// Closure called on every image change
    /// - Parameter newJPEGImageData: Cropped and resized JPEG image data of new chosen avatar.
    ///                               `nil` if image was deleted.
    /// - Returns: An image for the new avatar and if it is a default image (thus cannot be deleted)
    typealias ImageUpdated = (_ newJPEGImageData: Data?) -> (newAvatarImage: UIImage?, isDefaultImage: Bool)
    
    // MARK: - Private properties
    
    /// View controller used to present the pickers on
    private weak var presentingViewController: UIViewController?
    
    /// Temp anchor for popovers with picker & cropper views
    private var presentingRect: CGRect = .zero
    
    private var avatarImage: UIImage? {
        didSet {
            guard avatarImage != oldValue else {
                return
            }
            
            updateAvatarImageView()
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
        
        (strongSelf.avatarImage, strongSelf.isDefaultImage) = strongSelf.imageUpdated(nil)
    }
    
    private let imageUpdated: ImageUpdated
    
    private static let configuration = Configuration()
    
    // MARK: Subviews & layout
    
    private lazy var deleteButtonConstraints: [NSLayoutConstraint] = [
        deleteButton.topAnchor.constraint(equalTo: avatarImageView.topAnchor),
        deleteButton.trailingAnchor.constraint(equalTo: avatarImageView.trailingAnchor),
    ]
    
    private lazy var deleteButton = OpaqueDeleteButton(action: deleteAction)
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView(image: BundleUtil.imageNamed("Unknown"))
        
        imageView.contentMode = .scaleAspectFit
        // Aspect ratio: 1:1
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        // Fixed avatar size
        imageView.heightAnchor.constraint(equalToConstant: EditAvatarView.configuration.avatarSize).isActive = true
        
        // Needed such that delete button gets tap events
        imageView.isUserInteractionEnabled = true
        
        imageView.accessibilityIgnoresInvertColors = true
        
        return imageView
    }()
    
    private lazy var takePictureButton = CircleButton(
        sfSymbolName: "camera",
        accessibilityLabel: BundleUtil.localizedString(forKey: "take_photo")
    ) { [weak self] button in
        self?.showImagePicker(for: .camera, in: button)
    }
    
    private lazy var choosePictureButton = CircleButton(
        sfSymbolName: "photo.on.rectangle",
        accessibilityLabel: BundleUtil.localizedString(forKey: "choose_existing_photo")
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
        stackView.spacing = EditAvatarView.configuration.buttonSpacing
        stackView.distribution = .equalSpacing
        
        return stackView
    }()
    
    // MARK: Accessibility actions
    
    // This should be in sync with the button stack
    private lazy var accessibilityDefaultActions: [UIAccessibilityCustomAction] = {
        var actions = [UIAccessibilityCustomAction]()
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            actions.append(UIAccessibilityCustomAction(
                name: BundleUtil.localizedString(forKey: "take_photo"),
                target: self,
                selector: #selector(accessibilityShowCameraPicker)
            ))
        }
        
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            actions.append(UIAccessibilityCustomAction(
                name: BundleUtil.localizedString(forKey: "choose_existing_photo"),
                target: self,
                selector: #selector(accessibilityShowLibraryPicker)
            ))
        }
        
        return actions
    }()
    
    private lazy var accessibilityDeleteAction = UIAccessibilityCustomAction(
        name: BundleUtil.localizedString(forKey: "delete"),
        target: self,
        selector: #selector(accessibilityDeleteAvatar)
    )
    
    // MARK: - Lifecycle
    
    /// Create a new view to edit the provided avatar
    ///
    /// - Parameters:
    ///   - viewController: View controller to present the pickers on
    ///   - avatarImage:    Avatar image to show initially
    ///   - isDefaultImage: Is the provided image a default, that cannot be deleted
    ///   - isEditable:     Can the avatar actually be changed (including deletion)
    ///   - imageUpdated:   Closure called on every avatar image change
    init(
        in viewController: UIViewController,
        avatarImage: UIImage?,
        isDefaultImage: Bool,
        isEditable: Bool = true,
        imageUpdated: @escaping ImageUpdated
    ) {
        
        self.presentingViewController = viewController
        self.avatarImage = avatarImage
        self.isEditable = isEditable
        self.isDefaultImage = isDefaultImage
        self.imageUpdated = imageUpdated
        
        super.init(frame: .zero)
        
        configureStack()
        updateAvatarImageView()
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
        avatarImageView.addSubview(deleteButton)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        
        addArrangedSubview(avatarImageView)
        
        if isEditable {
            addArrangedSubview(buttonStack)
        }
        
        axis = .vertical
        alignment = .center
        spacing = EditAvatarView.configuration.verticalSpacing
        
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: 0,
            bottom: EditAvatarView.configuration.bottomSpacing,
            trailing: 0
        )
        isLayoutMarginsRelativeArrangement = true
        
        isAccessibilityElement = true
        
        if isEditable {
            accessibilityLabel = BundleUtil.localizedString(forKey: "edit_avatar_edit_picture_accessibility_label")
        }
        else {
            accessibilityLabel = BundleUtil.localizedString(forKey: "edit_avatar_picture_accessibility_label")
            accessibilityValue = BundleUtil.localizedString(forKey: "edit_avatar_picture_not_editable_accessibility")
        }
    }
    
    // MARK: - Update
    
    private func updateAvatarImageView() {
        guard avatarImage != nil else {
            avatarImageView.image = BundleUtil.imageNamed("Unknown")
            return
        }
        
        avatarImageView.image = avatarImage
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
                // No actions should be available if we cannot edit the avatar
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
    
    @objc private func accessibilityDeleteAvatar() -> Bool {
        deleteAction(deleteButton)
        return true
    }
}

// MARK: - UINavigationControllerDelegate, UIImagePickerControllerDelegate

extension EditAvatarView: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        
        guard let selectedImage = info[.originalImage] as? UIImage else {
            picker.dismiss(animated: true)
            
            if let presentingViewController {
                UIAlertTemplate.showAlert(
                    owner: presentingViewController,
                    title: BundleUtil.localizedString(forKey: "edit_avatar_no_image_found_title"),
                    message: BundleUtil.localizedString(forKey: "edit_avatar_no_image_found_message")
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

extension EditAvatarView: RSKImageCropViewControllerDelegate {
    func imageCropViewController(
        _ controller: RSKImageCropViewController,
        didCropImage croppedImage: UIImage,
        usingCropRect cropRect: CGRect,
        rotationAngle: CGFloat
    ) {
    
        let scaledImage = MediaConverter.scale(croppedImage, toMaxSize: CGFloat(kContactImageSize))
        let jpegImageData = scaledImage?
            .jpegData(compressionQuality: EditAvatarView.configuration.avatarJPEGCompressionQuality)
        
        (avatarImage, isDefaultImage) = imageUpdated(jpegImageData)
        
        controller.dismiss(animated: true)
    }

    func imageCropViewControllerDidCancelCrop(_ controller: RSKImageCropViewController) {
        controller.dismiss(animated: true)
    }
}
