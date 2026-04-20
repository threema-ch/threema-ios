@MainActor
protocol SystemPermissionsManagerProtocol {
    func hasVideoCapturePermission() async -> Bool
}

extension SystemPermissionsManagerProtocol where Self == SystemPermissionsManagerStub {
    static var alwaysAllows: any SystemPermissionsManagerProtocol {
        SystemPermissionsManagerStub(allows: true)
    }

    static var alwaysDenies: any SystemPermissionsManagerProtocol {
        SystemPermissionsManagerStub(allows: false)
    }
}

struct SystemPermissionsManagerStub: SystemPermissionsManagerProtocol {
    let allows: Bool

    init(allows: Bool) {
        self.allows = allows
    }

    func hasVideoCapturePermission() -> Bool { allows }
}
