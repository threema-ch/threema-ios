import argon2
import Foundation

/// Threema specific Swift bindings for Argon2 reference implementation
///
/// Usage: Directly call the static functions
public enum ThreemaArgon2 {
    
    /// Possible errors of hashing
    public enum Error: LocalizedError, Equatable {
        // Note: this is a subset of the `Argon2_ErrorCodes`
        
        case passwordTooShort
        case passwordTooLong
        
        case saltTooShort
        case saltTooLong
        
        case iterationsTooFew
        case iterationsTooMany
        
        case memoryTooLittle
        case memoryTooMuch
        
        case lanesTooFew
        case lanesTooMany
        
        case threadsTooFew
        case threadsTooMany
        
        case encodingFailed
        case decodingFailed
        
        case other(rawArgon2Error: Int32)
                
        init(_ argon2Error: Argon2_ErrorCodes) {
            switch argon2Error {
            case ARGON2_PWD_TOO_SHORT:
                self = .passwordTooShort
            case ARGON2_PWD_TOO_LONG:
                self = .passwordTooLong
            case ARGON2_SALT_TOO_SHORT:
                self = .saltTooShort
            case ARGON2_SALT_TOO_LONG:
                self = .saltTooLong
            case ARGON2_TIME_TOO_SMALL:
                self = .iterationsTooFew
            case ARGON2_TIME_TOO_LARGE:
                self = .iterationsTooMany
            case ARGON2_MEMORY_TOO_LITTLE:
                self = .memoryTooLittle
            case ARGON2_MEMORY_TOO_MUCH:
                self = .memoryTooMuch
            case ARGON2_LANES_TOO_FEW:
                self = .lanesTooFew
            case ARGON2_LANES_TOO_MANY:
                self = .lanesTooMany
            case ARGON2_THREADS_TOO_FEW:
                self = .threadsTooFew
            case ARGON2_THREADS_TOO_MANY:
                self = .threadsTooMany
            case ARGON2_ENCODING_FAIL:
                self = .encodingFailed
            case ARGON2_DECODING_FAIL:
                self = .decodingFailed
            default:
                self = .other(rawArgon2Error: argon2Error.rawValue)
            }
        }
        
        var argon2Error: Argon2_ErrorCodes {
            switch self {
            case .passwordTooShort:
                return ARGON2_PWD_TOO_SHORT
            case .passwordTooLong:
                return ARGON2_PWD_TOO_LONG
            case .saltTooShort:
                return ARGON2_SALT_TOO_SHORT
            case .saltTooLong:
                return ARGON2_SALT_TOO_LONG
            case .iterationsTooFew:
                return ARGON2_TIME_TOO_SMALL
            case .iterationsTooMany:
                return ARGON2_TIME_TOO_LARGE
            case .memoryTooLittle:
                return ARGON2_MEMORY_TOO_LITTLE
            case .memoryTooMuch:
                return ARGON2_MEMORY_TOO_MUCH
            case .lanesTooFew:
                return ARGON2_LANES_TOO_FEW
            case .lanesTooMany:
                return ARGON2_LANES_TOO_MANY
            case .threadsTooFew:
                return ARGON2_THREADS_TOO_FEW
            case .threadsTooMany:
                return ARGON2_THREADS_TOO_MANY
            case .encodingFailed:
                return ARGON2_ENCODING_FAIL
            case .decodingFailed:
                return ARGON2_DECODING_FAIL
            case let .other(rawArgon2Error: rawArgon2Error):
                return Argon2_ErrorCodes(rawArgon2Error)
            }
        }
        
        public var localizedDescription: String {
            String(cString: argon2_error_message(argon2Error.rawValue))
        }
    }
    
    /// Supported algorithm versions
    public enum Version: UInt32 {
        // We don't want to use v1_0, thus we don't expose it
        case v1_3 = 0x13
        
        public static let current = Version(rawValue: ARGON2_VERSION_NUMBER.rawValue)!
    }
    
    /// Hash lengths in bytes used in this implementation
    public enum HashLength: Int {
        case b32 = 32
        case b64 = 64
    }
    
    /// Hash the password with the ID type of Argon2 using `Version.current`
    ///
    /// - Parameters:
    ///   - password: Password to hash
    ///   - salt: Salt to use for hashing
    ///   - iterations: Number of hashing iterations (i.e. time cost)
    ///   - memoryInKiB: Memory usage in kibibytes
    ///   - threads: Number of threads (& compute lanes)
    ///   - desiredLength: Desired length of hash
    /// - Returns: Raw hash data
    public static func hashWithID(
        _ password: Data,
        with salt: Data,
        iterations: UInt32,
        memoryInKiB: UInt32,
        threads: UInt32,
        desiredLength: HashLength
    ) throws -> Data {
        try password.withUnsafeBytes { passwordBytes in
            try salt.withUnsafeBytes { saltBytes in
                var hash = Data(count: desiredLength.rawValue)
                
                let result = hash.withUnsafeMutableBytes { hashBytes in
                    argon2id_hash_raw(
                        iterations,
                        memoryInKiB,
                        threads,
                        passwordBytes.baseAddress,
                        passwordBytes.count,
                        saltBytes.baseAddress,
                        salt.count,
                        hashBytes.baseAddress,
                        hashBytes.count
                    )
                }
                
                let argon2error = Argon2_ErrorCodes(result)
                
                // Everything worked if the error is `ARGON2_OK`
                guard argon2error == ARGON2_OK else {
                    throw Error(argon2error)
                }
                
                return hash
            }
        }
    }
}
