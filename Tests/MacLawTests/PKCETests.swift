import Testing
@testable import MacLaw

@Test func codeVerifierLength() {
    let verifier = PKCEHelper.generateCodeVerifier()
    // Base64URL of 32 bytes = 43 characters (no padding)
    #expect(verifier.count == 43)
}

@Test func codeVerifierIsRandom() {
    let a = PKCEHelper.generateCodeVerifier()
    let b = PKCEHelper.generateCodeVerifier()
    #expect(a != b)
}

@Test func codeChallengeIsDeterministic() {
    let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    let c1 = PKCEHelper.computeCodeChallenge(verifier: verifier)
    let c2 = PKCEHelper.computeCodeChallenge(verifier: verifier)
    #expect(c1 == c2)
}

@Test func codeChallengeIsBase64URL() {
    let verifier = PKCEHelper.generateCodeVerifier()
    let challenge = PKCEHelper.computeCodeChallenge(verifier: verifier)
    // Base64URL: no +, /, or =
    #expect(!challenge.contains("+"))
    #expect(!challenge.contains("/"))
    #expect(!challenge.contains("="))
    #expect(!challenge.isEmpty)
}
