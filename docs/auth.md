# iOS Auth

Supabase anonymous sign-in. See `IOS_CONTRACT.md` § 1 for wire details.

## Flow
1. On first launch, call `supabase.auth.signInAnonymously()`.
2. Persist the **whole `Session`** (access + refresh tokens) in **Keychain**.
3. Every API call: `Authorization: Bearer <accessToken>`.
4. On 401 or near expiry, `supabase.auth.refreshSession()`, store the new session, retry once.

## Don't
- Don't generate UUIDs client-side and send them as `userId`. Server reads identity from the JWT.
- Don't store the session in `UserDefaults`. Keychain only.
