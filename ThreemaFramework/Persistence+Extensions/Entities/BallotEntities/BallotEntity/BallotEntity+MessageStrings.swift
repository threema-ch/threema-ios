import CocoaLumberjackSwift
import Foundation
import ThreemaMacros
import UIKit

extension BallotEntity {
    
    /// Readable string containing the names of the choices the local identity did vote for
    private var localizedLocalIdentityVotedChoices: String? {
        guard let myIdentity = MyIdentityStore.shared().identity,
              localIdentityDidVote(myIdentity: myIdentity), let choices, !choices.isEmpty else {
            return nil
        }
        var choiceNames = [String]()
        for choice in choices {
            if let myChoice = choice.getResultForIdentity(myIdentity)?.boolValue, myChoice {
                choiceNames.append(choice.name ?? "")
            }
        }
        
        guard !choiceNames.isEmpty else {
            return nil
        }
        
        // Add quotation marks
        let startQuote = #localize("quotation_mark_start")
        let endQuote = #localize("quotation_mark_end")
        let quotedChoices = choiceNames.map { "\(startQuote)\($0)\(endQuote)" }
        
        // Format list into a localized, readable String
        let joinedChoices = ListFormatter.localizedString(byJoining: quotedChoices)
        return String.localizedStringWithFormat(
            #localize("ballot_message_local_votes"),
            joinedChoices
        )
    }
    
    /// Readable string containing the names of the most voted choices
    private var localizedMostVotedChoices: String {
        let choices = namesOfChoicesMostVotedFor()
        guard !choices.isEmpty else {
            return #localize("ballot_message_no_votes")
        }
        
        // Add quotation marks
        let startQuote = #localize("quotation_mark_start")
        let endQuote = #localize("quotation_mark_end")
        let quotedChoices = choices.map { "\(startQuote)\($0)\(endQuote)" }
        
        // Format list into a localized, readable String
        let joinedChoices = ListFormatter.localizedString(byJoining: quotedChoices)
        return String.localizedStringWithFormat(
            #localize("ballot_message_most_votes"),
            joinedChoices
        )
    }
    
    /// A String containing the number of participants that have participated
    private var localizedParticipantsVoted: String {
        guard let myIdentity = MyIdentityStore.shared().identity else {
            fatalError("My identity is missing")
        }

        var votersCount = voters(myIdentity: myIdentity).count
        if localIdentityDidVote(myIdentity: myIdentity) {
            votersCount += 1
        }
        
        let participantsCount = conversationParticipantsCount
        
        return String.localizedStringWithFormat(
            #localize("ballot_message_did_vote"),
            String(votersCount),
            String(participantsCount)
        )
    }
    
    /// Secondary text used in the closing message of ballots
    public var localizedClosingMessageText: String {
        guard let myIdentity = MyIdentityStore.shared().identity else {
            fatalError("My identity is missing")
        }

        var string = #localize("ballot_message_closed")
        
        let newline = "\n"
        
        string.append(newline)
        let mostVoted = localizedMostVotedChoices
        string.append(mostVoted)
        
        if let choices = localizedLocalIdentityVotedChoices {
            string.append(newline)
            string.append(choices)
        }
        
        if numberOfReceivedVotes(myIdentity: myIdentity) != 0,
           displayMode?.intValue != BallotDisplayMode.summary.rawValue {
            string.append(newline)
            let participants = localizedParticipantsVoted
            string.append(participants)
        }
        
        return string
    }
    
    /// Secondary text for a ballot, includes icon
    public func localizedMessageSecondaryText(
        configuration: UIImage.Configuration? = nil
    ) -> NSMutableAttributedString {
        
        let text: String =
            // Assign the correct text and icon depending on state of ballot
            if !isClosed {
                if let choices = localizedLocalIdentityVotedChoices {
                    choices
                }
                else {
                    if displayMode?.intValue == BallotDisplayMode.summary.rawValue ||
                        (!isIntermediate && creatorID != MyIdentityStore.shared().identity) {
                        #localize("ballot_message_tap_to_vote")
                    }
                    else {
                        localizedParticipantsVoted
                    }
                }
            }
            else {
                localizedMostVotedChoices
            }
        
        let attributedString = NSMutableAttributedString(string: text)

        // Symbol
        if let symbol = stateSymbol, let configuration {
            
            let configuredSymbol = symbol.withConfiguration(configuration)
            
            // Create attributed strings
            let symbolAttachment = NSTextAttachment(image: configuredSymbol)
            let symbolString = NSAttributedString(attachment: symbolAttachment)
            let spaceString = NSAttributedString(string: " ")
            
            // Combine strings
            attributedString.insert(spaceString, at: 0)
            attributedString.insert(symbolString, at: 0)
        }
        
        return attributedString
    }
    
    public var stateSymbol: UIImage? {
        guard let myIdentity = MyIdentityStore.shared().identity else {
            DDLogError("My identity is missing")
            return nil
        }

        if !isClosed {
            if localIdentityDidVote(myIdentity: myIdentity) {
                return UIImage(systemName: "checkmark.circle")?
                    .withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
            }
            else {
                return UIImage(systemName: "circle")?
                    .withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal)
            }
        }
        else {
            let color = localIdentityDidVote(myIdentity: myIdentity) ? .primary : UIColor
                .secondaryLabel
            return UIImage(systemName: "checkmark.circle.fill")?
                .withTintColor(color, renderingMode: .alwaysOriginal)
        }
    }
}
