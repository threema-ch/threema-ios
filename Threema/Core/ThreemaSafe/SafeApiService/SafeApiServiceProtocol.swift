protocol SafeApiServiceProtocol {
    @available(*, deprecated, message: "testServer(server:user:password:) async throws -> Data")
    func testServer(
        server: URL,
        user: String?,
        password: String?,
        completionHandler: @escaping (() throws -> Data) -> Void
    )

    func testServer(server: URL, user: String?, password: String?) async throws -> Data

    func delete(
        server: URL,
        user: String?,
        password: String?,
        completion: @escaping (String?) -> Void
    )

    func upload(
        backup: URL,
        user: String?,
        password: String?,
        encryptedData: [UInt8],
        completionHandler: @escaping (Data?, String?) -> Void
    )

    func download(
        backup: URL,
        user: String?,
        password: String?,
        completionHandler: @escaping (() throws -> Data?) -> Void
    )
}
