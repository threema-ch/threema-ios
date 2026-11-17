import Testing
import UIKit
@testable import Threema

@MainActor
struct ThreemaTabTests {

    @Test("Every tab's identifier maps back to the same tab", arguments: ThreemaTab.allCases)
    func identifierRoundTrip(tab: ThreemaTab) {
        #expect(ThreemaTab(identifier: tab.identifier) == tab)
    }

    @Test("Identifiers are unique and namespaced")
    func identifiersAreUniqueAndNamespaced() {
        let identifiers = ThreemaTab.allCases.map(\.identifier)

        #expect(Set(identifiers).count == identifiers.count)
        #expect(identifiers.allSatisfy { $0.hasPrefix("ch.threema.tab.") })
    }

    @Test("An unknown identifier maps to no tab")
    func unknownIdentifierMapsToNoTab() {
        #expect(ThreemaTab(identifier: "ch.threema.tab.unknown") == nil)
    }

    @Test("The tab order is contacts, conversations, profile, settings")
    func tabOrder() {
        #expect(ThreemaTab.allCases == [.contacts, .conversations, .profile, .settings])
    }

    @Test("App destinations map onto their tabs")
    func destinationsMapOntoTabs() {
        #expect(ThreemaTab(.contacts) == .contacts)
        #expect(ThreemaTab(.conversations) == .conversations)
        #expect(ThreemaTab(.profile) == .profile)
        #expect(ThreemaTab(.settings) == .settings)
    }

    @Test("makeTab vends a UITab carrying identifier, title and the given view controller")
    func makeTabCarriesIdentifierTitleAndViewController() {
        let viewController = UIViewController()

        let tab = ThreemaTab.settings.makeTab(viewController: viewController)

        #expect(tab.identifier == ThreemaTab.settings.identifier)
        #expect(tab.title == ThreemaTab.settings.title)
        #expect(tab.viewController === viewController)
    }

    @Test("Tabs use the default placement so the iPad tab bar shows their titles")
    func tabsUseDefaultPlacement() {
        for threemaTab in ThreemaTab.allCases {
            #expect(threemaTab.makeTab(viewController: UIViewController()).preferredPlacement == .automatic)
        }
    }
}
