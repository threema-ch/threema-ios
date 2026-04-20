import Foundation

struct Address {
    let ip: String
    let port: UInt32
    
    var protocolVersion: IPAdressProtocolVersion {
        // Regular expression to match IPv4 address
        guard let ipv4Regex = try? NSRegularExpression(pattern: "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$") else {
            return .unknown
        }
        
        // Regular expression to match IPv6 address
        guard let ipv6Regex = try? NSRegularExpression(pattern: "^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$") else {
            return .unknown
        }
        
        if ipv4Regex.firstMatch(in: ip, options: [], range: NSRange(location: 0, length: ip.utf16.count)) != nil {
            return .ipv4
        }
        else if ipv6Regex
            .firstMatch(in: ip, options: [], range: NSRange(location: 0, length: ip.utf16.count)) != nil {
            return .ipv6
        }
        else {
            return .unknown
        }
    }
}
