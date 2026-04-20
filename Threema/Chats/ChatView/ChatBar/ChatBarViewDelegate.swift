import UIKit

protocol ChatBarViewDelegate: AnyObject {
    // Sending or previewing items
    func canSendText() -> Bool
    func sendText(rawText: String)
    func sendTypingIndicator(startTyping: Bool)
    func sendOrPreviewPastedItem() -> Bool
    @available(iOS 18.0, *)
    func processAndSendGlyph(_ glyph: NSAdaptiveImageGlyph)
    func showAssetsSelector()
    func showCamera()
    func showImagePicker()
    func checkIfPastedStringIsMedia() -> Bool
    func showContact(identity: String)
    func isEditedMessageSet() -> Bool

    // Voice Messages
    func startRecording(with audioFileURL: URL?)
    
    // Animations
    func updateLayoutForTextChange()

    func setIsResettingKeyboard(_ setReset: Bool)
}
