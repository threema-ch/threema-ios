import CocoaLumberjackSwift
import Foundation

final class MentionsHelper {
    let loggerEnabled = false
    var currentMentionRange: NSRange?
    var currMention = ""
    var lastChangeFoundMatches = false
    
    func couldBeMention(text: String, location: NSRange) -> String? {
        defer { if loggerEnabled {
            runLogger(text: text, location: location, currMention: currMention)
        } }
        
        // 0. Check if we could be entering a new mention. This is the case if the last text did not find any matches
        // and we have just entered an @ character
        // 1. Check if the newly inserted text and the current mention overlap
        // 1. a) If they do not overlap reset mentions
        // 1. b) If they overlap continue
        // 2. Insert new text into currMention
        // 3. return getPossibleMentions
        
        let isNewMention = (!lastChangeFoundMatches && text == "@")
        
        if let couldBeMentionStart = currentMentionRange, !isNewMention {
            let editIntersection = NSIntersectionRange(couldBeMentionStart, location)
            let textNSLength = (text as NSString).length
            if couldBeMentionStart.upperBound + textNSLength >= location.location,
               couldBeMentionStart.lowerBound <= location.lowerBound {
                // We are currently editing our mention
                if !text.isEmpty {
                    currentMentionRange = NSMakeRange(
                        couldBeMentionStart.location,
                        couldBeMentionStart.length + textNSLength
                    )
                }
                else {
                    currentMentionRange = NSMakeRange(
                        couldBeMentionStart.location,
                        couldBeMentionStart.length - location.length
                    )
                }

                if NSEqualRanges(editIntersection, couldBeMentionStart), text.isEmpty {
                    resetMentions()
                    return nil
                }

                let currMentionNS = currMention as NSString
                let newLocation = max(0, location.location - (couldBeMentionStart.location + 1))
                let newLength = min(currMentionNS.length, location.length)
                let replacementRange = NSMakeRange(newLocation, newLength)

                // This fixes an issue where in some languages text gets replace by iOS with a shorter string
                guard textNSLength >= replacementRange.length || text == "" else {
                    resetMentions()
                    return nil
                }

                // Validate range is within bounds of the current mention string
                guard replacementRange.location + replacementRange.length <= currMentionNS.length else {
                    resetMentions()
                    return nil
                }

                currMention = currMentionNS.replacingCharacters(in: replacementRange, with: text)
            }
            else {
                // We are not currently editing our mention and therefore reset the mention context.
                resetMentions()
                return nil
            }
        }
        else {
            // There is no current mention. Check if we are adding another mention
            if text == "@" {
                // We only allow interactive mentions when entering the at as a single character i.e. by entering it
                // from the keyboard
                currentMentionRange = location
                // Reset currMention
                currMention = ""
            }
            else {
                resetMentions()
                return nil
            }
        }
        
        DDLogVerbose("Mention State: \(String(describing: currentMentionRange)) - \"\(currMention)\"")
        
        return currMention
    }
    
    func runLogger(text: String, location: NSRange, currMention: String) {
        DDLogVerbose("MentionHelper Input: text \"\(text)\" location \(location)")
        DDLogVerbose(
            "Testcaseformatter: (\"\(text)\", NSMakeRange(\(location.location), \(location.length)), \"\(currMention)\"),"
        )
    }
    
    func resetMentions() {
        currMention = ""
        currentMentionRange = nil
    }
    
    func getReplacementRange(fullText: NSString) -> NSRange {
        guard let couldBeMentionStart = currentMentionRange else {
            fatalError("Oh well")
        }
        
        let mentionRange = NSMakeRange(couldBeMentionStart.location, couldBeMentionStart.length + 1)
        
        let replaceRange = fullText.range(
            of: "@\(currMention)",
            options: String.CompareOptions.caseInsensitive,
            range: mentionRange,
            locale: nil
        )
        
        resetMentions()
        return replaceRange
    }
    
    func getReplacementText(identity: String) -> String {
        "@[\(identity)]"
    }
}
