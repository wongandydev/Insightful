# Rules — Insightful (iOS)

Read before starting any iOS task.

## Testing
- For UI changes, **build and run the app**. Type checks ≠ feature works.
- Add tests when behavior is non-obvious or has historically broken. Skip them for trivial views.
- Test names are `[unitOfWork][State][ExpectedBehavior]` in pure camelCase. No underscores between parts. Examples: `sendWhenStatus401RefreshesTokenAndRetriesOnce`, `goalContextWhenContractFixtureDecodesAllFields`.
- **Use Given / When / Then structure.** Every test has literal `// Given`, `// When`, `// Then` comments. One behavior per test. All `#expect` calls live in the Then block — never scatter assertions across setup or action sections.

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
- **No default values in initializer parameters.** Every `init` call site spells out what it's passing. Defaults hide which wire-up is actually in use and obscure the composition graph. The composition root (`AppDependencies.live()`) is where all real wiring happens; defaults aren't needed for ergonomics there. Regular methods may still use defaults when they help.
- **Doc comments follow Apple's DocC conventions.** Every `///` comment has a one-sentence summary, an optional discussion paragraph, and `- Parameters:` / `- Returns:` / `- Throws:` sections where applicable. Cross-reference other symbols with double-backtick syntax (`` ``HealthKitMetric/kind`` ``) so Xcode Quick Help links them — never write a bare `.case` and leave readers to grep.

## Concurrency
- **Default actor isolation is nonisolated.** The project no longer sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- Annotate `@MainActor` **only** on UI types — `View`s, view models that drive a `View`, and anything that touches UIKit/AppKit.
- Plain models, networking types, services, and value types stay nonisolated. They get used from URLSession callbacks and tests on background threads; making them MainActor by default causes hangs and surprise warnings.

## Wire format
- All JSON keys exchanged with the backend are **camelCase**. Both directions, including nested objects.
- If a backend payload arrives with snake_case, that is a backend contract bug — file it. Do **not** paper over it long-term with `CodingKeys` adapters in Swift.
- See `IOS_CONTRACT.md` for the authoritative list of endpoints and shapes.

## Ask first
- Before adding a new SPM dependency.
- Before requesting new HealthKit data types (Info.plist usage strings + re-prompt).
