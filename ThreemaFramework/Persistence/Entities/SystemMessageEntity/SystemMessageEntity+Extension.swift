import Foundation

extension SystemMessageEntity {
    
    public func argumentAsUTF8String() -> String {
        guard let arg, let decodedArgs = String(data: arg, encoding: .utf8) else {
            return ""
        }
        return decodedArgs
    }
    
    public func callDuration() -> String? {
        guard let dict = argumentDictionary(), let duration = dict["CallTime"] as? String, !duration.isEmpty else {
            return nil
        }
        
        return duration
    }
    
    private func argumentDictionary() -> [String: Any]? {
        guard let arg, !arg.isEmpty else {
            return nil
        }
        
        do {
            guard let jsonObject = try JSONSerialization
                .jsonObject(with: arg, options: .fragmentsAllowed) as? [String: Any] else {
                return nil
            }
            return jsonObject
        }
        catch {
            return nil
        }
    }
}
