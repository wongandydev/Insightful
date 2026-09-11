# iOS Auth

Supabase auth. See `IOS_CONTRACT.md` § 1 for wire details.

## Identities
A user starts **anonymous** and can attach a **durable identity** — an Apple ID
or an email + password — from Settings. Attaching preserves `auth.users.id`, so
goals and insights stay with the user. The two cannot be merged: an Apple ID
that already owns an account can't be attached to a second one.

## Flow
1. Cold start: restore the SDK's cached session, or `signInAnonymously()`.
2. The whole `Session` lives in **Keychain** (SDK default store).
3. Every API call: `Authorization: Bearer <accessToken>`.
4. On 401, `refreshSession()`, store the new session, retry once.
5. Sign-out routes to `RootRoute.signIn` — Apple, email + password, or
   "continue without an account" (a fresh anonymous user). Re-running the cold
   start there would have stranded an account holder on a new anonymous
   identity with no way back.

## Don't
- Don't generate UUIDs client-side and send them as `userId`. Server reads
  identity from the JWT.
- Don't store the session in `UserDefaults`. Keychain only.
- Don't map every `client.session` throw to "no session" — only
  `AuthError.sessionMissing` means that. See `SupabaseAuthBackend.currentSession()`.
