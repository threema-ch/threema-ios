//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

import Foundation
import UIKit

extension Ballot {
    
    /// Readable string containing the names of the choices the local identity did vote for
    private var localizedLocalIdentityVotedChoices: String? {
        guard localIdentityDidVote(), let choices = choices as? Set<BallotChoice> else {
            return nil
        }
        var choiceNames = [String]()
        for choice in choices {
            if let myChoice = choice.getOwnResult()?.boolValue(), myChoice {
                choiceNames.append(choice.name)
            }
        }
        
        // Add quotation marks
        let startQuote = BundleUtil.localizedString(forKey: "quotation_mark_start")
        let endQuote = BundleUtil.localizedString(forKey: "quotation_mark_end")
        let quotedChoices = choiceNames.map { "\(startQuote)\($0)\(endQuote)" }
        
        // Format list into a localized, readable String
        let joinedChoices = ListFormatter.localizedString(byJoining: quotedChoices)
        return String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "ballot_message_local_votes"),
            joinedChoices
        )
    }
    
    /// Readable string containing the names of the most voted choices
    private var localizedMostVotedChoices: String {
        guard let choices = mostVotedChoices() as? [String],
              !choices.isEmpty else {
            return BundleUtil.localizedString(forKey: "ballot_message_no_votes")
        }
        
        // Add quotation marks
        let startQuote = BundleUtil.localizedString(forKey: "quotation_mark_start")
        let endQuote = BundleUtil.localizedString(forKey: "quotation_mark_end")
        let quotedChoices = choices.map { "\(startQuote)\($0)\(endQuote)" }
        
        // Format list into a localized, readable String
        let joinedChoices = ListFormatter.localizedString(byJoining: quotedChoices)
        return String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "ballot_message_most_votes"),
            joinedChoices
        )
    }
    
    /// A String containing the number of participants that have participated
    private var localizedParticipantsVoted: String {
        var votersCount = voters().count
        if localIdentityDidVote() {
            votersCount += 1
        }
        
        let participantsCount = conversationParticipantsCount()
        
        return String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "ballot_message_did_vote"),
            String(votersCount),
            String(participantsCount)
        )
    }
    
    /// Secondary text used in the closing message of ballots
    public var localizedClosingMessageText: String {
        var string = BundleUtil.localizedString(forKey: "ballot_message_closed")
        
        let newline = "\n"
        
        string.append(newline)
        let mostVoted = localizedMostVotedChoices
        string.append(mostVoted)
        
        if let choices = localizedLocalIdentityVotedChoices {
            string.append(newline)
            string.append(choices)
        }
        
        if numberOfReceivedVotes() != 0 {
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
        
        var text: String
        
        // Assign the correct text and icon depending on state of ballot
        if !isClosed() {
            if let choices = localizedLocalIdentityVotedChoices {
                text = choices
            }
            else {
                text = localizedParticipantsVoted
            }
        }
        else {
            text = localizedMostVotedChoices
        }
        
        let attributedString = NSMutableAttributedString(string: text)

        // Symbol
        if let symbol = stateSymbol, let configuration = configuration {
            
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
        
        if !isClosed() {
            if localIdentityDidVote() {
                return UIImage(systemName: "checkmark.circle")?
                    .withTintColor(Colors.green, renderingMode: .alwaysOriginal)
            }
            else {
                return UIImage(systemName: "circle")?
                    .withTintColor(Colors.textLight, renderingMode: .alwaysOriginal)
            }
        }
        else {
            let color = localIdentityDidVote() ? Colors.primary : Colors.textLight
            return UIImage(systemName: "checkmark.circle.fill")?
                .withTintColor(color, renderingMode: .alwaysOriginal)
        }
    }
}
