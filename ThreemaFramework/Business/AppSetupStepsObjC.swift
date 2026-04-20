@available(swift, obsoleted: 1.0, renamed: "AppSetupSteps", message: "Only use from Objective-C")
public final class AppSetupStepsObjC: NSObject {
    let appSetupSteps = AppSetupSteps()
    
    @objc public func run() async throws {
        try await appSetupSteps.run()
    }
}
