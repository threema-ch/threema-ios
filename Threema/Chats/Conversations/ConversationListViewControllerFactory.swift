struct ConversationListViewControllerFactory: DelegateFactory {
    let isRegularSizeClass: () -> Bool
    let isLoadedInBackground: Bool
    let isAppInBackground: () -> Bool
    
    init(
        isRegularSizeClass: @autoclosure @escaping () -> Bool,
        isLoadedInBackground: Bool,
        isAppInBackground: @autoclosure @escaping () -> Bool
    ) {
        self.isRegularSizeClass = isRegularSizeClass
        self.isLoadedInBackground = isLoadedInBackground
        self.isAppInBackground = isAppInBackground
    }
    
    func make(
        with delegate: ConversationListViewControllerDelegate
    ) -> ConversationListViewController {
        let conversationListViewController = ConversationListViewController(
            delegate: delegate,
            isRegularSizeClass: isRegularSizeClass(),
            isLoadedInBackground: isLoadedInBackground,
            isAppInBackground: isAppInBackground()
        )
        
        let tab = ThreemaTab(.conversations)
        conversationListViewController.tabBarItem = tab.tabBarItem
        conversationListViewController.title = tab.title
        
        return conversationListViewController
    }
}
