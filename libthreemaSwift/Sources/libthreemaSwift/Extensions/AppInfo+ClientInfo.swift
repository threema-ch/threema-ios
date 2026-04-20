import ThreemaEssentials

extension AppInfo {
    public func asClientInfo() -> ClientInfo {
        .ios(
            version: version,
            locale: locale,
            deviceModel: deviceModel,
            osVersion: osVersion
        )
    }
}
