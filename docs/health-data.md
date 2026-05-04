# Health Data on iOS

## Apple Health (on-device)
- Read via HealthKit. Request only the data types we actually need.
- Read on-device, then POST a normalized payload to the backend.
- Reads happen in `HealthKitService` — never inside a view or view model.

## Whoop (planned)
- User initiates connection from the app. App opens the Whoop OAuth URL provided by the backend.
- Backend handles the token exchange and ongoing sync.
- App never holds Whoop tokens.

## Posting to backend
- Dates as `YYYY-MM-DD` in the user's **local** timezone (see `IOS_CONTRACT.md` § 2).
- Batch reads — don't fire one request per metric.
