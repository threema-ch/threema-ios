import Testing
@testable import Threema

struct TabSelectionStateTests {

    @Test("Selecting a different tab reports the switch and remembers the new tab")
    func switchingTabsReportsTheSwitch() {
        var state = TabSelectionState(selectedTab: .conversations)

        let transition = state.select(.profile)

        #expect(transition == .switched(from: .conversations))
        #expect(state.selectedTab == .profile)
    }

    @Test("Selecting the current tab is a reselection, not a switch")
    func reselectingTheCurrentTab() {
        var state = TabSelectionState(selectedTab: .conversations)

        #expect(state.select(.conversations) == .reselected)
        #expect(state.selectedTab == .conversations)
    }

    @Test("A switch reported twice (user tap and delegate, or programmatic and delegate) acts once")
    func duplicateReportsOfOneSwitchActOnce() {
        var state = TabSelectionState(selectedTab: .conversations)

        #expect(state.select(.settings) == .switched(from: .conversations))
        #expect(state.select(.settings) == .reselected)
    }

    @Test("Returning to a tab is a switch from the tab being left")
    func returningToATabIsASwitchFromTheLeftTab() {
        var state = TabSelectionState(selectedTab: .conversations)
        _ = state.select(.contacts)

        #expect(state.select(.conversations) == .switched(from: .contacts))
    }

    @Test("Inactive tabs are every tab but the selected one, in tab order")
    func inactiveTabsExcludeTheSelectedTab() {
        var state = TabSelectionState(selectedTab: .conversations)

        #expect(state.inactiveTabs == [.contacts, .profile, .settings])

        _ = state.select(.settings)

        #expect(state.inactiveTabs == [.contacts, .conversations, .profile])
    }
}
