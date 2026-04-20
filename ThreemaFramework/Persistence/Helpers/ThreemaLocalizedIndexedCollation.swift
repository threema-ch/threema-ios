import Foundation
import UIKit

public enum ThreemaLocalizedIndexedCollation {
    public static var sectionIndexTitles: [String] {
        UILocalizedIndexedCollation.current().sectionIndexTitles + ["*"]
    }
    
    public static var sectionTitles: [String] {
        UILocalizedIndexedCollation.current().sectionTitles + ["*"]
    }
    
    public static func section(forSectionIndexTitle indexTitleIndex: Int) -> Int {
        sectionTitles.firstIndex(of: sectionIndexTitles[indexTitleIndex]) ?? UILocalizedIndexedCollation.current()
            .sectionTitles.count - 1
    }
   
    public static func section(for str: String) -> Int {
        guard let char = str.uppercased().first else {
            return sectionIndexTitles.count - 1
        }
        
        return section(
            forSectionIndexTitle: sectionIndexTitles.firstIndex(of: "\(char)") ?? sectionIndexTitles
                .count - 2
        )
    }
    
    public static func section(for letter: Character) -> Int {
        section(forSectionIndexTitle: sectionIndexTitles.firstIndex(of: "\(letter)") ?? sectionIndexTitles.count - 2)
    }
}
