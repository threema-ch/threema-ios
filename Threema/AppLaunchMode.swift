import ThreemaFramework

enum AppLaunchMode {
    static var isTestingOrPreviewing: Bool {
        #if DEBUG
            return ProcessInfoHelper.isRunningForPreviews
                || ProcessInfoHelper.isRunningForPlaygrounds
                || ProcessInfoHelper.isRunningForTests
        #else
            return false
        #endif
    }
}
