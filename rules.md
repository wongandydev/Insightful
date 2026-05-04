# Rules — Insightful (iOS)

Read before starting any iOS task.

## Testing
- For UI changes, **build and run the app**. Type checks ≠ feature works.
- Add tests when behavior is non-obvious or has historically broken. Skip them for trivial views.

## Commits
- One logical change per commit. Subject ≤ 70 chars, imperative mood.
- Body explains *why*, not *what*.
- Never commit signing certs, API keys, or `.env`-style files.
- Never `--no-verify` or skip hooks.

## Code style
- SwiftUI + Apple `Observation` (`@Observable`). No Combine, no `ObservableObject`.
- async/await. No completion handlers.
- URLSession only. No third-party networking libs.
- One `@Observable` view model per feature screen. Views stay dumb.
- No protocols on services unless we actually need to swap implementations.
- Decode all backend responses through typed DTOs. Validate at the network boundary; trust internal calls.
- Store the Supabase session in **Keychain**, never `UserDefaults`.

## Ask first
- Before adding a new SPM dependency.
- Before requesting new HealthKit data types (Info.plist usage strings + re-prompt).
