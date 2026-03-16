import Foundation
import Testing
@testable import MacLaw

@Test func keychainPrefixDetected() {
    #expect("@keychain:test-key".hasPrefix("@keychain:"))
    #expect(!"plain-value".hasPrefix("@keychain:"))
}
