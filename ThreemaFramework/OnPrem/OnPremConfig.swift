import Foundation

public struct OnPremConfig: Decodable, Sendable {
    let version: String
    let signatureKey: Data
    let refresh: Int
    let license: OnPremLicense
    let chat: OnPremConfigChat
    let directory: OnPremConfigDirectory
    let blob: OnPremConfigBlob
    let avatar: OnPremConfigAvatar?
    let safe: OnPremConfigSafe?
    let work: OnPremConfigWork?
    let mediator: OnPremConfigMediator?
    let web: OnPremConfigWeb?
    let rendezvous: OnPremConfigRendezvous?
    let domains: OnPremConfigDomains?
    let maps: OnPremConfigMaps?
}
