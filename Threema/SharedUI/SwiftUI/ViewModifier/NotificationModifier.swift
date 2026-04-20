import Combine
import SwiftUI
import ThreemaFramework

struct NotificationModifier<Value>: ViewModifier {
    @Environment(\.appContainer)
    private var appContainer: AppContainer
    
    typealias NotificationKey = KeyPath<AppEnvironment, AnyNotificationPublisher<Value>>
    typealias Handler = (AnyNotificationPublisher<Value>.Output) -> Void
    
    var keyPath: NotificationKey
    var block: Handler
    
    func body(content: Content) -> some View {
        content
            .onReceive(
                appContainer.appEnvironment[keyPath: keyPath],
                perform: block
            )
    }
}

extension View {
    func onReceive<Value>(
        _ keyPath: NotificationModifier<Value>.NotificationKey,
        _ block: @escaping NotificationModifier<Value>.Handler
    ) -> some View {
        modifier(NotificationModifier(
            keyPath: keyPath,
            block: block
        ))
    }
}
