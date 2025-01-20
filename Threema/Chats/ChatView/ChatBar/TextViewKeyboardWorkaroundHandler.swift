//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

/// Workaround to approximate expected behavior in an input field
///
/// Adds workarounds for issues not fixed in IOS-2560, notably we add approximations for the double tap space to add a
/// period and removing spaces before punctuations
/// marks entered after the previous word was auto corrected or auto completed.
///
/// Behavior is consistent with what a correct implementation would offer as of iOS 15 but might drift from future iOS
/// versions without manual checks.
final class TextViewKeyboardWorkaroundHandler {
    private var debugPrinting = false
    
    private var debugTiming = false

    private var lastTextChange: (text: String, date: Date)?
    private var prePreviousWordMightHaveBeenAutoCorrected = false
    private var prePreviousCharacterWasSpace = false
    
    init(debugTiming: Bool = false) {
        self.debugTiming = debugTiming
    }
    
    func nextTextViewChange(
        shouldChangeTextIn adjustedRange: NSRange,
        replacementText text: String,
        oldText oldParsedText: NSMutableAttributedString
    ) -> (range: NSRange, fullText: NSMutableAttributedString, newText: String) {
        let actualText: String
        let maxDiff = 0.5
        
        let newChange: (range: NSRange, fullText: NSMutableAttributedString, newText: String)

        // Handle the case where we want to double tap the space bar to enter a period and then a space
        // This happens in two cases
        // 1. the last text change was a space, the current text change is a space and the time interval between the two
        //    is short
        // 2. the last text change was a space, the current text change is a space and the text before the previous was
        //    longer than one character i.e. most likely added through auto-correct (or copy-pasted)
        if let lastTextChange, lastTextChange.text == " ", text == " ",
           Date().timeIntervalSince(lastTextChange.date) < maxDiff ||
           prePreviousWordMightHaveBeenAutoCorrected || debugTiming,
           !prePreviousCharacterWasSpace {
            
            // Replaces one character with `actualText`. Adds more characters from `actualText` if actual text is longer
            // than one character.
            let rangeModifier = 1
            let newRange = NSRange(location: adjustedRange.location - rangeModifier, length: rangeModifier)
            
            actualText = "."
            
            newChange = (newRange, oldParsedText, actualText)
        }
        // Handle the case where we want to remove the space before a punctuation mark if the space
        else if prePreviousWordMightHaveBeenAutoCorrected,
                ["?", "!", "."].contains(where: { $0 == text }) {
            let rangeModifier = lastTextChange?.text == " " ? 1 : 0
            let newRange = NSRange(location: adjustedRange.location - rangeModifier, length: rangeModifier)
            actualText = text + " "
            newChange = (newRange, oldParsedText, actualText)
        }
        else {
            actualText = text
            newChange = (adjustedRange, oldParsedText, actualText)
        }
        
        // If the previous text was longer than one character or an emoji and the current text is a space we should not
        // check the timing for double tap to space on the next invocation as the previous text was most likely entered
        // through auto correct and the space was added by the system instead of the user.
        prePreviousWordMightHaveBeenAutoCorrected = text.count > 1 ||
            ((lastTextChange?.text.count ?? -1) > 1 && text == " ") ||
            lastTextChange?.text.isSingleEmoji ?? false

        if adjustedRange.length != 0 {
            prePreviousCharacterWasSpace = [""].contains(lastTextChange?.text)
        }
        else {
            prePreviousCharacterWasSpace = [" ", "."].contains(lastTextChange?.text)
        }
        
        lastTextChange = (actualText, Date())
        
        if debugPrinting {
            DDLogVerbose("""
                ((NSMakeRange(\(adjustedRange.location), \(adjustedRange.length)), \
                NSMutableAttributedString(string: "\(oldParsedText.string)"), "\(text)"), \
                (NSMakeRange(\(newChange.range.location), \(newChange.range.length)), \
                NSMutableAttributedString(string: "\(newChange.fullText.string)"), "\(newChange.newText)")),
                """)
        }
        
        return newChange
    }
}
