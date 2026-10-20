public protocol ChatTextViewDelegate: AnyObject {
    func canStartEditing() -> Bool
    func chatTextViewDidChange(_ textView: ChatTextView)
    func checkIfPastedStringIsMedia() -> Bool
    func didEndEditing()
    func processAndSendGlyph(_ glyph: NSAdaptiveImageGlyph)

    func sendText()
    func textView(_ textView: ChatTextView, editMenuFor textRange: UITextRange, suggestedActions: [UIMenuElement])
        -> UIMenu?
    func textView(_ textView: ChatTextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction?
}
