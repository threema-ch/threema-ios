import Testing

@testable import Threema

@Suite("Threema Safe Password Validation Tests")
struct ThreemaSafePasswordValidatorTests {
    @Test("When password is too short it should return a validation error")
    func short() async throws {
        let sut = ThreemaSafePasswordValidator()
        let passwordShort = "abcdefg"
        let result = sut.validate(
            password: passwordShort,
            passwordConfirmation: passwordShort,
            regexPattern: nil,
            regexErrorMessage: nil
        )

        guard case let .error(title, message) = result else {
            Issue.record("Expected an `error` result, but got `\(result)` instead.")
            return
        }

        #expect(title == "Password too short")
        #expect(message == "The password is too short. Please enter at least 8 characters.")
    }

    @Test("When passwords are different it should return a validation error")
    func different() async throws {
        let sut = ThreemaSafePasswordValidator()
        let password = "abcdefghijkl"
        let confirmation = "abcdefgh"
        let result = sut.validate(
            password: password,
            passwordConfirmation: confirmation,
            regexPattern: nil,
            regexErrorMessage: nil
        )

        guard case let .error(title, message) = result else {
            Issue.record("Expected an `error` result, but got `\(result)` instead.")
            return
        }

        #expect(title == "Password mismatch")
        #expect(message == "The passwords that you have entered do not match. Please go back and try again.")
    }

    @Test("When password has repeating characters it should return a validation warning")
    func repeatingChars() async throws {
        let passwordWithRepeatingCharacters = "aaaaaaaa"
        let sut = ThreemaSafePasswordValidator()
        let result = sut.validate(
            password: passwordWithRepeatingCharacters,
            passwordConfirmation: passwordWithRepeatingCharacters,
            regexPattern: nil,
            regexErrorMessage: nil
        )

        guard case let .warning(title, message) = result else {
            Issue.record("Expected an `warning` result, but got `\(result)` instead.")
            return
        }

        #expect(title == "Weak password")
        #expect(
            message == """
                The selected password for Threema Safe is not secure and can be easily guessed by attackers. \
                Please choose another one. Hint: Use a password composed of multiple individual words.
                """
        )
    }

    @Test("When password has repeating numbers it should return a validation warning")
    func repeatingNumbers() async throws {
        let passwordWithOnlyNumbers = "87654321"
        let sut = ThreemaSafePasswordValidator()
        let result = sut.validate(
            password: passwordWithOnlyNumbers,
            passwordConfirmation: passwordWithOnlyNumbers,
            regexPattern: nil,
            regexErrorMessage: nil
        )

        guard case let .warning(title, message) = result else {
            Issue.record("Expected an `warning` result, but got `\(result)` instead.")
            return
        }

        #expect(title == "Weak password")
        #expect(
            message == """
                The selected password for Threema Safe is not secure and can be easily guessed by attackers. \
                Please choose another one. Hint: Use a password composed of multiple individual words.
                """
        )
    }

    @Test(
        "When password is blacklisted it should return a validation warning",
        arguments: ["0okmnji9", "1111111a", "zzzz1111"]
    )
    func blacklisted(_ blacklistedPassword: String) async throws {
        let sut = ThreemaSafePasswordValidator()
        let result = sut.validate(
            password: blacklistedPassword,
            passwordConfirmation: blacklistedPassword,
            regexPattern: nil,
            regexErrorMessage: nil
        )

        guard case let .warning(title, message) = result else {
            Issue.record(
                """
                Expected an `warning` result for iteration parameter `\(blacklistedPassword)`, \
                but got `\(result)` instead.
                """
            )
            return
        }

        #expect(title == "Weak password")
        #expect(
            message == """
                The selected password for Threema Safe is not secure and can be easily guessed by attackers. \
                Please choose another one. Hint: Use a password composed of multiple individual words.
                """
        )
    }

    @Test("When password does not comply with guidelines it should return a validation error with enforced message")
    func guidelinesEnforcedMessage() async throws {
        let sut = ThreemaSafePasswordValidator()
        let regexPattern = "^[a-z]{4}[0-9]{4}$"
        let regexErrorMessage = "This message should be shown when regex pattern is not verified by the password."

        let passwordNotConformingToRegexPattern = "1234abcd"

        let result = sut.validate(
            password: passwordNotConformingToRegexPattern,
            passwordConfirmation: passwordNotConformingToRegexPattern,
            regexPattern: regexPattern,
            regexErrorMessage: regexErrorMessage
        )

        guard case let .error(title, message) = result else {
            Issue.record("Expected an `error` result, but got `\(result)` instead.")
            return
        }

        #expect(title == "Password")
        #expect(message == regexErrorMessage)
    }

    @Test("When password does not comply with guidelines it should return a validation error with default message")
    func guidelineDefaultMessage() async throws {
        let sut = ThreemaSafePasswordValidator()
        let regexPattern = "^[a-z]{4}[0-9]{4}$"

        let passwordNotConformingToRegexPattern = "1234abcd"

        let result = sut.validate(
            password: passwordNotConformingToRegexPattern,
            passwordConfirmation: passwordNotConformingToRegexPattern,
            regexPattern: regexPattern,
            regexErrorMessage: nil
        )

        guard case let .error(title, message) = result else {
            Issue.record("Expected an `error` result, but got `\(result)` instead.")
            return
        }

        #expect(title == "Password")
        #expect(message == "The entered password does not comply with the guidelines.")
    }

    @Test("When password complies with guidelines it should return a valid result")
    func guidelinesValidated() async throws {
        let sut = ThreemaSafePasswordValidator()
        let regexPattern = "^[a-z]{4}[0-9]{4}$"

        let passwordNotConformingToRegexPattern = "abcd1234"

        let result = sut.validate(
            password: passwordNotConformingToRegexPattern,
            passwordConfirmation: passwordNotConformingToRegexPattern,
            regexPattern: regexPattern,
            regexErrorMessage: nil
        )

        guard case .valid = result else {
            Issue.record("Expected a `valid` result, but got `\(result)` instead.")
            return
        }
    }

    @Test("When enforced guidelines are not valid it should return validation error")
    func guidelinesNotValidated() async throws {
        let sut = ThreemaSafePasswordValidator()
        let regexPattern = "^[a-z{4[0-9]{4}$"

        let passwordNotConformingToRegexPattern = "abcd1234"

        let result = sut.validate(
            password: passwordNotConformingToRegexPattern,
            passwordConfirmation: passwordNotConformingToRegexPattern,
            regexPattern: regexPattern,
            regexErrorMessage: nil
        )

        guard case let .error(title, message) = result else {
            Issue.record("Expected an `error` result, but got `\(result)` instead.")
            return
        }

        #expect(title == "Password")
        #expect(
            message == """
                Invalid definition (regex) of password requirements. Please contact your Threema administrator.
                """
        )
    }

    @Test("When password is valid it should return a valid result")
    func validPassword() async throws {
        let sut = ThreemaSafePasswordValidator()
        let validPassword = "ABcd!@#tgk092"

        let result = sut.validate(
            password: validPassword,
            passwordConfirmation: validPassword,
            regexPattern: nil,
            regexErrorMessage: nil
        )

        guard case .valid = result else {
            Issue.record("Expected a `valid` result, but got `\(result)` instead.")
            return
        }
    }
}
