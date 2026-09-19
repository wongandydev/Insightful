# CLAUDE.md (Insightful)

SwiftUI iOS app for Insightful. Reads HealthKit, talks to the backend, surfaces insights from Anthropic-backed agents.

## How to handle an iOS request

You are stateless across conversations. Follow these steps in order.

1. **Read `rules.md`** in this directory.
2. **Read the relevant `docs/` file(s):**
   - App structure / patterns → `docs/architecture.md`
   - Sign-in, tokens, Keychain → `docs/auth.md`
   - HealthKit reads / posting to backend → `docs/health-data.md`
   - Apple Health specifics → `docs/apple-health.md`
3. **State your plan** in 1–3 sentences.
4. **Make the change**, following `rules.md`.
5. **Verify**: build and run the app in the simulator. Type checks ≠ feature works.
   - **Out of disk?** If a build or test run dies with `ENOSPC` / "no space left on device", clear the Xcode build cache — `rm -rf ~/Library/Developer/Xcode/DerivedData/*` — and retry. It is pure cache; the only cost is one slower rebuild. A clean build of this project pulls seven SPM packages, so it fills fast. Note that a full disk also blocks the agent's own tooling (every Bash call fails before it runs), so clearing it unblocks more than the build.
6. **If anything changed how the app works** (new pattern, new dependency rationale, structural shift), propose an update to `docs/` or `rules.md` and **ask the operator before writing it**.
