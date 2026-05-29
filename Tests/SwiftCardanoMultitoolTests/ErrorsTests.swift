import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("SwiftCardanoMultitoolError")
struct SwiftCardanoMultitoolErrorTests {

    @Test("unsupportedNetwork includes network name")
    func unsupportedNetwork() {
        let error = SwiftCardanoMultitoolError.unsupportedNetwork("preprod")
        #expect(error.errorDescription == "Network not supported: preprod")
    }

    @Test("fileNotFound includes path")
    func fileNotFound() {
        let path = FilePath("/tmp/missing.json")
        let error = SwiftCardanoMultitoolError.fileNotFound(path)
        #expect(error.errorDescription?.contains("/tmp/missing.json") == true)
    }

    @Test("fileAlreadyExists includes path")
    func fileAlreadyExists() {
        let path = FilePath("/tmp/existing.json")
        let error = SwiftCardanoMultitoolError.fileAlreadyExists(path)
        #expect(error.errorDescription?.contains("/tmp/existing.json") == true)
    }

    @Test("jsonError includes message")
    func jsonError() {
        let error = SwiftCardanoMultitoolError.jsonError("unexpected key")
        #expect(error.errorDescription == "JSON Error: unexpected key")
    }

    @Test("invalidHex includes the hex string")
    func invalidHex() {
        let error = SwiftCardanoMultitoolError.invalidHex("ZZZZ")
        #expect(error.errorDescription == "Invalid hexadecimal string: ZZZZ")
    }

    @Test("invalidConfiguration includes config detail")
    func invalidConfiguration() {
        let error = SwiftCardanoMultitoolError.invalidConfiguration("missing network field")
        #expect(error.errorDescription == "Invalid configuration: missing network field")
    }

    @Test("invalidAddress includes message")
    func invalidAddress() {
        let error = SwiftCardanoMultitoolError.invalidAddress("addr1xyz")
        #expect(error.errorDescription == "Invalid Address: addr1xyz")
    }

    @Test("missingField includes field name")
    func missingField() {
        let error = SwiftCardanoMultitoolError.missingField("poolId")
        #expect(error.errorDescription == "Missing required field: poolId")
    }

    @Test("encryptionError includes message")
    func encryptionError() {
        let error = SwiftCardanoMultitoolError.encryptionError("key derivation failed")
        #expect(error.errorDescription == "Encryption Error: key derivation failed")
    }

    @Test("decryptionError includes message")
    func decryptionError() {
        let error = SwiftCardanoMultitoolError.decryptionError("wrong password")
        #expect(error.errorDescription == "Decryption Error: wrong password")
    }

    @Test("gpgNotFound has static message")
    func gpgNotFound() {
        let error = SwiftCardanoMultitoolError.gpgNotFound
        #expect(error.errorDescription == "GPG binary not found in system PATH")
    }

    @Test("gpgFailed includes message")
    func gpgFailed() {
        let error = SwiftCardanoMultitoolError.gpgFailed("exit code 2")
        #expect(error.errorDescription == "GPG operation failed: exit code 2")
    }

    @Test("notImplemented with message")
    func notImplementedWithMessage() {
        let error = SwiftCardanoMultitoolError.notImplemented("coming soon")
        #expect(error.errorDescription == "coming soon")
    }

    @Test("notImplemented without message uses default")
    func notImplementedNoMessage() {
        let error = SwiftCardanoMultitoolError.notImplemented(nil)
        #expect(error.errorDescription == "This feature is not yet implemented")
    }

    @Test("operationError includes message")
    func operationError() {
        let error = SwiftCardanoMultitoolError.operationError("timeout")
        #expect(error.errorDescription == "Operation Error: timeout")
    }

    @Test("valueError includes message")
    func valueError() {
        let error = SwiftCardanoMultitoolError.valueError("out of range")
        #expect(error.errorDescription == "Value Error: out of range")
    }

    @Test("adahandleOfflineMode has static message")
    func adahandleOfflineMode() {
        let error = SwiftCardanoMultitoolError.adahandleOfflineMode
        #expect(error.errorDescription == "AdaHandles are only supported in online or lite mode")
    }

    @Test("adahandleNotFound includes handle")
    func adahandleNotFound() {
        let error = SwiftCardanoMultitoolError.adahandleNotFound("$myhandle")
        #expect(error.errorDescription == "Could not resolve AdaHandle: $myhandle")
    }

    @Test("adahandleAPIError with HTTP code includes code")
    func adahandleAPIErrorWithCode() {
        let error = SwiftCardanoMultitoolError.adahandleAPIError("rate limited", 429)
        #expect(error.errorDescription == "AdaHandle API Error (HTTP 429): rate limited")
    }

    @Test("adahandleAPIError without HTTP code omits code")
    func adahandleAPIErrorNoCode() {
        let error = SwiftCardanoMultitoolError.adahandleAPIError("unknown error", nil)
        #expect(error.errorDescription == "AdaHandle API Error: unknown error")
    }
}

@Suite("AddressInfoError")
struct AddressInfoErrorTests {

    @Test("missingIdentifier has static message")
    func missingIdentifier() {
        let error = AddressInfoError.missingIdentifier
        #expect(error.errorDescription == "AddressInfo requires at least one of: address, addressFile, or adaHandle")
    }

    @Test("invalidAddress includes details")
    func invalidAddress() {
        let error = AddressInfoError.invalidAddress("bad prefix")
        #expect(error.errorDescription == "Invalid address: bad prefix")
    }

    @Test("unresolvedAdaHandle includes handle")
    func unresolvedAdaHandle() {
        let error = AddressInfoError.unresolvedAdaHandle("$test")
        #expect(error.errorDescription == "Ada handle resolution not yet implemented for: $test")
    }

    @Test("cliError includes details")
    func cliError() {
        let error = AddressInfoError.cliError("command not found")
        #expect(error.errorDescription == "CLI error: command not found")
    }

    @Test("decodeError includes details")
    func decodeError() {
        let error = AddressInfoError.decodeError("invalid JSON")
        #expect(error.errorDescription == "Decode error: invalid JSON")
    }
}
