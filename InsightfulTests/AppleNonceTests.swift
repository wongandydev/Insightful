import CryptoKit
import Foundation
import Testing
@testable import Insightful

@Suite
struct AppleNonceTests {

    @Test
    func hashedWhenInitializedIsSHA256HexOfRaw() {
        // Given
        let nonce = AppleNonce()

        // When
        let digest = SHA256.hash(data: Data(nonce.raw.utf8))

        // Then
        #expect(nonce.hashed == digest.map { String(format: "%02x", $0) }.joined())
    }

    @Test
    func rawWhenInitializedIs32BytesHexEncoded() {
        // Given
        let nonce = AppleNonce()

        // When
        let raw = nonce.raw

        // Then
        #expect(raw.count == 64)
        #expect(raw.allSatisfy { $0.isHexDigit })
    }

    @Test
    func initWhenCalledTwiceProducesDistinctRawValues() {
        // Given
        let first = AppleNonce()

        // When
        let second = AppleNonce()

        // Then
        #expect(first.raw != second.raw)
    }
}

@Suite
struct AppleNonceStoreTests {

    @Test
    func spendWhenRequestBegunReturnsRawHalfOfIssuedNonce() {
        // Given
        var store = AppleNonceStore()
        let hashed = store.begin()

        // When
        let raw = store.spend()

        // Then
        let digest = SHA256.hash(data: Data((raw ?? "").utf8))
        #expect(digest.map { String(format: "%02x", $0) }.joined() == hashed)
    }

    @Test
    func spendWhenNonceAlreadySpentReturnsNil() {
        // Given
        var store = AppleNonceStore()
        _ = store.begin()
        _ = store.spend()

        // When
        let raw = store.spend()

        // Then
        #expect(raw == nil)
    }

    @Test
    func spendWhenNoRequestBegunReturnsNil() {
        // Given
        var store = AppleNonceStore()

        // When
        let raw = store.spend()

        // Then
        #expect(raw == nil)
    }

    @Test
    func spendAfterDiscardReturnsNil() {
        // Given
        var store = AppleNonceStore()
        _ = store.begin()
        store.discard()

        // When
        let raw = store.spend()

        // Then
        #expect(raw == nil)
    }

    @Test
    func beginWhenRequestAlreadyPendingReplacesTheHeldNonce() {
        // Given
        var store = AppleNonceStore()
        _ = store.begin()
        let second = store.begin()

        // When
        let raw = store.spend()

        // Then
        let digest = SHA256.hash(data: Data((raw ?? "").utf8))
        #expect(digest.map { String(format: "%02x", $0) }.joined() == second)
    }
}
