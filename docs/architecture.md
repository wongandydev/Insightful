# iOS App Architecture

## Stack
- SwiftUI
- Apple **Observation** framework (`@Observable`) — not Combine, not `ObservableObject`.
- async/await for all async work. No completion handlers.
- Supabase Swift SDK for auth.
- URLSession for everything else. No third-party networking libs.

## Layout (`Insightful/Insightful/`)
Keep flat and obvious. Folders:
- `App/` — `InsightfulApp.swift`, `AppDependencies.swift`, root scene
- `Networking/` — `APIClient`, `APIRequest`, `APIError`, `Endpoints`, `HTTPClient`, `JSONCoding`
- `Features/<Feature>/` — view + view model + feature-local value types (e.g. `ChatMessage`, `RootRoute`). `GoalSummary/` is the one feature without a view model — it's purely presentational and is reached from two surfaces (the post-setup route and a Settings drill-down), so it takes its callbacks directly via `init`. `onContinue` is optional so Settings can present it without the onboarding "continue" button.
- `Services/` — `AuthService`, `UserService`, `GoalService`, `InsightService`, `HealthKitService`
- `Models/` — DTOs decoded from the backend

## Conventions
- One `@Observable` view model per feature screen.
- Views are dumb: read state, render, dispatch intents.
- Errors `throw` and are caught at the view-model boundary, surfaced as user-facing state via the VM's `errorMessage` / `phase` / `AppError` state.
- **No protocols on services unless we actually need to swap implementations.** In practice the swap reason is *view-model tests* using actor-based fakes (`FakeGoalService`, `FakeHealthKitService`, `FakeInsightService`, `FakeUserService`, `FakeAuthBackend`). When a VM under test needs to stub a service, the service gets a `<Name>Servicing` protocol that the prod struct/actor and the fake both conform to. Otherwise, services stay concrete.
- **Composition root: `AppDependencies.live()`.** Production wiring lives there — all real `init`s happen once, then `InsightfulApp` decomposes the struct into individual `let` properties and passes them down by name. See `rules.md` for the "no default values in initializer parameters" rule that keeps this graph explicit.
- **Dependency injection is explicit via `init`, not `.environment`.** Each feature view's `init` takes the services it actually uses; `RootView` is the only place that knows the full dependency graph for the current route.

## Testing patterns

Tests follow the GWT structure and naming rules in `rules.md`. Two specific patterns worth calling out:

- **Actor-based fakes for VM tests.** Each `<Name>Servicing` protocol has a matching `Fake<Name>Service` actor under `InsightfulTests/Support/`. The fake exposes `program*(_:)` helpers that take a `Result` and record call arguments — see `FakeGoalService` for the canonical shape.
- **Sendable error constraint in fakes is a known leak.** Actor storage requires Sendable values, so `program*(_:)` requires errors to conform to `Error & Sendable`. That's stricter than the protocols declare (`throws`, untyped). Tracked as a TODO on `InsightServicing`.
