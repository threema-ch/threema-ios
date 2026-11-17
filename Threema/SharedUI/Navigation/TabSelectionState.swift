import Foundation

/// Selection bookkeeping for `ThreemaTabBarController`, free of UIKit so the rules are testable:
/// - a change of tab acts exactly once, however many sources report it (user tap, programmatic switch, delegate),
/// - entering a tab the user left before is what triggers passcode re-authentication,
/// - a memory warning only targets inactive tabs.
struct TabSelectionState: Equatable {

    enum Transition: Equatable {
        /// The tab was already selected: a same-tab re-tap, or a duplicate report of a switch already handled
        case reselected
        /// A different tab became selected
        case switched(from: ThreemaTab)
    }

    private(set) var selectedTab: ThreemaTab

    init(selectedTab: ThreemaTab) {
        self.selectedTab = selectedTab
    }

    /// Records `tab` as selected and reports whether that is a change
    mutating func select(_ tab: ThreemaTab) -> Transition {
        guard tab != selectedTab else {
            return .reselected
        }

        let previous = selectedTab
        selectedTab = tab
        return .switched(from: previous)
    }

    /// Every tab except the selected one, in tab order
    var inactiveTabs: [ThreemaTab] {
        ThreemaTab.allCases.filter { $0 != selectedTab }
    }
}
