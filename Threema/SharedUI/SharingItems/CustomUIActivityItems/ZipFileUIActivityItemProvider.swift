final class ZipFileUIActivityItemProvider: UIActivityItemProvider, @unchecked Sendable {
    private var url: URL
    private var subject = ""

    init(url: URL, subject: String) {
        self.url = url
        self.subject = subject
        super.init(placeholderItem: url)
    }

    override public var item: Any {
        url
    }

    override func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        subject
    }

    override func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "com.pkware.zip-archive"
    }
}
