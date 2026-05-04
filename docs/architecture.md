# iOS App Architecture

## Stack
- SwiftUI
- Apple **Observation** framework (`@Observable`) — not Combine, not `ObservableObject`.
- async/await for all async work. No completion handlers.
- Supabase Swift SDK for auth.
- URLSession for everything else. No third-party networking libs.

## Layout (`Insightful/Insightful/`)
Keep flat and obvious. Suggested folders as it grows:
- `App/` — `InsightfulApp.swift`, root scene
- `Features/<Feature>/` — view + view model + feature-local types
- `Services/` — `AuthService`, `APIClient`, `HealthKitService`, etc.
- `Models/` — DTOs decoded from the backend

## Conventions
- One `@Observable` view model per feature screen.
- Views are dumb: read state, render, dispatch intents.
- No protocols on services unless we actually need to swap implementations.
- Errors `throw` and are caught at the view-model boundary, surfaced as user-facing state.
