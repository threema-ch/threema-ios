import Combine
import SwiftUI
import ThreemaFramework

@available(*, deprecated, message: "Do not use anymore.")
@dynamicMemberLookup
struct AppContainer: EnvironmentKey {
    
    let appEnvironment: AppEnvironment
 
    static var defaultValue: Self { self.default }
    
    private static let `default` =
        Self(appEnvironment: AppEnvironment(businessInjector: BusinessInjector(forBackgroundProcess: false)))
    
    subscript<T>(dynamicMember keyPath: KeyPath<AppEnvironment, T>) -> T {
        appEnvironment[keyPath: keyPath]
    }
    
    subscript<T>(dynamicMember keyPath: KeyPath<BusinessInjectorProtocol, T>) -> T {
        appEnvironment.businessInjector[keyPath: keyPath]
    }
}

extension EnvironmentValues {
    @available(*, deprecated, message: "Do not use anymore.")
    var appContainer: AppContainer {
        get { self[AppContainer.self] }
        set { self[AppContainer.self] = newValue }
    }
}

extension View {
    @available(*, deprecated, message: "Do not use anymore.")
    func inject(_ container: AppContainer) -> some View {
        environment(\.appContainer, container)
    }
}
