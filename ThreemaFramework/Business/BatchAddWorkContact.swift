import Foundation

public final class BatchAddWorkContact: NSObject, Sendable {
    let identity: String
    let publicKey: Data?
    let firstName: String?
    let lastName: String?
    let csi: String?
    let jobTitle: String?
    let department: String?
    let availabilityStatus: WorkAvailabilityStatus?
   
    required init(
        identity: String,
        publicKey: Data?,
        firstName: String?,
        lastName: String?,
        csi: String?,
        jobTitle: String?,
        department: String?,
        availabilityStatus: WorkAvailabilityStatus?
    ) {
        self.identity = identity
        self.publicKey = publicKey
        self.firstName = firstName
        self.lastName = lastName
        self.csi = csi
        self.jobTitle = jobTitle
        self.department = department
        self.availabilityStatus = availabilityStatus
    }
    
    override public var description: String {
        "\(identity): \(firstName ?? "no firstname set") \(lastName ?? "no lastname set"), \(csi ?? "no csi set"), \(jobTitle ?? "no job title set"), \(department ?? "no department set")"
    }
}
