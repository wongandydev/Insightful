# Apple Health

## Where it runs
On-device, in the iOS app, via HealthKit.

## Flow
1. App requests HealthKit authorization for the specific data types it needs.
2. `HealthKitService` reads metrics (sleep, HRV, workouts, resting HR, etc.).
3. App POSTs a normalized payload to the backend.
4. Backend writes to Supabase, keyed to `auth.uid()`.
5. Agents read from Supabase when generating insights.

## Notes
- Read-only for our purposes. We do not write back to HealthKit.
- Request the **minimum** set of types. Adding new ones requires updating Info.plist usage strings and re-prompting the user.
- Backend treats missing data as "not yet synced," not "user has none."
