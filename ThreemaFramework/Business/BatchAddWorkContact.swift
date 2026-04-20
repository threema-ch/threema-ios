import Foundation

class BatchAddWorkContact: NSObject, @unchecked Sendable {
    let identity: String
    let publicKey: Data?
    let firstName: String?
    let lastName: String?
    let csi: String?
    let jobTitle: String?
    let department: String?
    
    @objc required init(
        identity: String,
        publicKey: Data?,
        firstName: String?,
        lastName: String?,
        csi: String?,
        jobTitle: String?,
        department: String?
    ) {
        self.identity = identity
        self.publicKey = publicKey
        self.firstName = firstName
        self.lastName = lastName
        self.csi = csi
        self.jobTitle = jobTitle
        self.department = department
    }
    
    override var description: String {
        "\(identity): \(firstName ?? "no firstname set") \(lastName ?? "no lastname set"), \(csi ?? "no csi set"), \(jobTitle ?? "no job title set"), \(department ?? "no department set")"
    }
}
