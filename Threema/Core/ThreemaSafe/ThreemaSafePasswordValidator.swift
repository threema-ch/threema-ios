import CocoaLumberjackSwift
import ThreemaMacros

struct ThreemaSafePasswordValidator {
    // MARK: - Public types

    enum ValidationResult {
        case valid(String)
        case error(title: String, message: String)
        case warning(title: String, message: String)
    }

    // MARK: - Public methods

    func validate(
        password: String,
        passwordConfirmation: String,
        regexPattern: String?,
        regexErrorMessage: String?
    ) -> ValidationResult {
        if let regexPattern {
            validateRegexPattern(password, regexPattern, regexErrorMessage)
        }
        else if passwordIsTooShort(password) {
            .error(
                title: #localize("password_too_short_title"),
                message: #localize("password_too_short_message")
            )
        }
        else if passwordsAreDifferent(password, passwordConfirmation) {
            .error(
                title: #localize("password_mismatch_title"),
                message: #localize("password_mismatch_message")
            )
        }
        else if passwordIsBad(password: password) {
            .warning(
                title: #localize("password_bad"),
                message: .localizedStringWithFormat(
                    #localize("password_bad_explain"),
                    TargetManager.localizedAppName
                )
            )
        }
        else {
            .valid(password)
        }
    }

    // MARK: - Helpers

    private func passwordIsTooShort(_ password: String) -> Bool {
        password.count < kMinimumPasswordLength
    }

    private func passwordsAreDifferent(_ password: String, _ passwordConfirmation: String) -> Bool {
        !password.elementsEqual(passwordConfirmation)
    }

    private func validateRegexPattern(
        _ password: String,
        _ regexPattern: String,
        _ regexErrorMessage: String?
    ) -> ValidationResult {
        do {
            let isValid = try isPasswordPatternValid(password: password, regExPattern: regexPattern)
            if isValid {
                return .valid(password)
            }
            else {
                return .error(
                    title: #localize("Password"),
                    message: regexErrorMessage ?? #localize("password_bad_guidelines")
                )
            }
        }
        catch {
            return .error(
                title: #localize("Password"),
                message: .localizedStringWithFormat(
                    #localize("password_bad_regex"),
                    TargetManager.appName
                )
            )
        }
    }

    private func passwordIsBad(password: String) -> Bool {
        if checkBadPasswordToRegEx(password: password) {
            true
        }
        else {
            checkPasswordToFile(password: password)
        }
    }

    private func checkPasswordToFile(password: String) -> Bool {

        guard let filePath = Bundle.main.path(forResource: "bad_passwords", ofType: "txt"),
              let fileHandle = FileHandle(forReadingAtPath: filePath) else {

            return false
        }

        defer {
            fileHandle.closeFile()
        }

        let delimiter = Data(String(stringLiteral: "\n").utf8)
        let chunkSize = 4096
        var isEof = false
        var lineStart = ""

        while !isEof {
            var position = 0
            let chunk = fileHandle.readData(ofLength: chunkSize)
            if chunk.isEmpty {
                isEof = true
            }

            // compare password with all lines within the chunk
            repeat {
                var line = ""
                if let range = chunk.subdata(in: position..<chunk.count).range(of: delimiter) {
                    if !lineStart.isEmpty {
                        line.append(lineStart)
                        lineStart = ""
                    }
                    line
                        .append(String(
                            data: chunk.subdata(in: position..<position + range.lowerBound),
                            encoding: .utf8
                        )!)
                    position += range.upperBound
                }
                else {
                    // store start characters of next line/chunk
                    if chunk.count > position,
                       let start = String(data: chunk.subdata(in: position..<chunk.count), encoding: .utf8) {
                        lineStart = start
                    }
                    position = chunk.count
                }

                if !line.isEmpty, line == password {
                    return true
                }
            }
            while chunk.count > position
        }

        return false
    }

    private func checkBadPasswordToRegEx(password: String) -> Bool {
        let checks = [
            "(.)\\1+", // do not allow single repeating characters
            "^[0-9]{1,15}$",
        ] // do not allow numbers only

        do {
            for check in checks {
                let regex = try NSRegularExpression(pattern: check, options: .caseInsensitive)
                let result = regex.matches(
                    in: password,
                    options: NSRegularExpression.MatchingOptions(rawValue: 0),
                    range: NSRange(location: 0, length: password.count)
                )

                // result must match once the whole password/string
                if result.count == 1, result[0].range.location == 0, result[0].range.length == password.count {
                    return true
                }
            }
        }
        catch {
            DDLogError("Regex failed to check password: \(error.localizedDescription)")
        }

        return false
    }

    private func isPasswordPatternValid(password: String, regExPattern: String) throws -> Bool {
        var regExMatches = 0
        let regEx = try NSRegularExpression(pattern: regExPattern)
        regExMatches = regEx.numberOfMatches(
            in: password,
            options: [],
            range: NSRange(location: 0, length: password.count)
        )
        return regExMatches == 1
    }
}
