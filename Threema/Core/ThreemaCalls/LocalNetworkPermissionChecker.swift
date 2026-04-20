import Network

final class LocalNetworkPermissionChecker {
    func checkLocalNetworkPermission(completion: @escaping (Bool) -> Void) {
        // We use a dummy service type that doesn't actually exist
        let browser = NWBrowser(for: .bonjour(type: "_privacy-check._tcp", domain: nil), using: .tcp)
        var isDenied = false
        
        browser.stateUpdateHandler = { state in
            switch state {
            case let .waiting(error), let .failed(error):
                if case let .dns(dnsError) = error, dnsError == -65570 {
                    isDenied = true
                }
            case .ready:
                isDenied = false
            default:
                break
            }
        }
        
        browser.start(queue: .main)
        
        // We give the system 0.3 to 0.5 seconds to "object" to the connection.
        // This is usually enough time for the Privacy Daemon to trigger the failure.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            browser.cancel()
            // If the 'isDenied' flag was tripped during this window, we return false.
            completion(!isDenied)
        }
    }
}
