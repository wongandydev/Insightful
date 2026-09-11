import CryptoKit
import Foundation

/// The nonce pair for a single Sign in with Apple request.
///
/// Apple embeds the hash of the request nonce into the identity token, and
/// Supabase re-hashes the raw value to confirm the token was minted for this
/// request. `ASAuthorizationAppleIDRequest.nonce` carries ``hashed``; the
/// token exchange carries ``raw``.
struct AppleNonce {
    /// The value handed to Supabase alongside the identity token.
    let raw: String
    /// The SHA-256 digest of ``raw``, hex encoded, set on the Apple request.
    let hashed: String

    /// Creates a nonce from 32 bytes of randomness.
    ///
    /// Swift's default random number generator is `arc4random_buf` on Apple
    /// platforms, so the bytes are suitable for use as a cryptographic nonce.
    init() {
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max) }
        raw = Self.hex(bytes)
        hashed = Self.hex(Array(SHA256.hash(data: Data(raw.utf8))))
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

/// Holds the raw nonce for the Sign in with Apple request currently in flight.
///
/// Apple's authorization callback arrives long after the request was made, so
/// the raw half has to survive in memory between the two. Exactly one request
/// is in flight at a time: ``begin()`` issues a nonce, ``spend()`` hands the
/// raw value over once, and ``discard()`` drops it when an attempt ends
/// without an exchange — a cancelled sheet must not leave a nonce a later
/// exchange could spend.
struct AppleNonceStore {
    private var pending: AppleNonce?

    /// Issues a nonce for a new request, replacing any nonce still held.
    ///
    /// - Returns: The hashed value to set on
    ///   `ASAuthorizationAppleIDRequest.nonce`.
    mutating func begin() -> String {
        let nonce = AppleNonce()
        pending = nonce
        return nonce.hashed
    }

    /// Consumes the held nonce.
    ///
    /// - Returns: The raw value to send alongside the identity token, or `nil`
    ///   when no request is in flight.
    mutating func spend() -> String? {
        defer { pending = nil }
        return pending?.raw
    }

    /// Drops the held nonce, ending the in-flight request without an exchange.
    mutating func discard() {
        pending = nil
    }
}
