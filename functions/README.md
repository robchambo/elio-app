# Elio Cloud Functions

Operator notes for the `functions/` directory. Code lives in `src/`, compiles to `lib/` via `tsc`.

## Deployed functions (as of Sprint 17)

| Function | Region | Trigger | Purpose |
|---|---|---|---|
| `generateImportAddress` | us-central1 | callable | Per-user inbox token generator (Sprint 16.8 order import) |
| `postmarkInbound` | us-central1 | HTTPS | Postmark Inbound webhook → `pending_imports/` (Sprint 16.8) |
| `crashlyticsFatal` | us-east1 | Firebase Alerts (`onNewFatalIssuePublished`) | Upsert Notion Crashes row |
| `crashlyticsNonfatal` | us-east1 | Firebase Alerts (`onNewNonfatalIssuePublished`) | Upsert Notion Crashes row |
| `crashlyticsVelocity` | us-east1 | Firebase Alerts (`onVelocityAlertPublished`) | Upsert Notion Crashes row |
| `crashlyticsRegression` | us-east1 | Firebase Alerts (`onRegressionAlertPublished`) | Upsert Notion Crashes row |

**Region split:** Crashlytics handlers must be in `us-east1` (Firebase Alerts events only fire there for `elio-prototype`). Everything else lives in `us-central1` (default).

## Deploy

From repo root:

```
firebase deploy --only functions
```

Or a single function:

```
firebase deploy --only functions:postmarkInbound
```

Builds via the predeploy hook in `firebase.json` (`npm --prefix functions run build`). The TypeScript compile must succeed before deploy proceeds.

## Secrets

Set via Firebase Secret Manager (NOT environment variables — code reads them at runtime via `defineSecret`):

| Secret | Used by | Set with |
|---|---|---|
| `NOTION_TOKEN` | All `crashlytics*` handlers | `firebase functions:secrets:set NOTION_TOKEN` |
| `POSTMARK_INBOUND_USER` | `postmarkInbound` (Basic Auth verify) | `firebase functions:secrets:set POSTMARK_INBOUND_USER` |
| `POSTMARK_INBOUND_PASSWORD` | `postmarkInbound` (Basic Auth verify) | `firebase functions:secrets:set POSTMARK_INBOUND_PASSWORD` |
| `GEMINI_API_KEY` | `postmarkInbound` parser; future `generateRecipeStream` | `firebase functions:secrets:set GEMINI_API_KEY` |

After rotating a secret, re-deploy the dependent function so the new value is bound.

## Notion Crashes pipe — schema-drift caveat

`src/index.ts:78-118` maps Crashlytics payloads to the Notion Crashes DB properties (`Title`, `Issue ID`, `Type`, `Status`, `Crashlytics URL`, `App version`, `Count`). **If you rename a property in Notion, update `buildProperties` to match — the Notion API errors out on unknown property names and the safeUpsert catch swallows the error, so the drift surfaces only as silently-stale rows.** Crashes DB id: `32affae3-cb5e-4256-b4f5-a81692f35b72`.

Idempotency key: Crashlytics `Issue ID`. Velocity + Regression alerts for an already-tracked issue update the existing row instead of creating duplicates.

## Local dev

```
cd functions
npm install
npm run build:watch
```

For emulator runs:

```
firebase emulators:start --only functions
```

## Logs

```
firebase functions:log --only crashlyticsFatal
```

Or open the function in the Firebase Console → Logs tab for filtered views.

## Forward-compat — Tier 3 auto-triage

The Crashes DB has empty `Claude analysis` + `Linked PR` columns that the Crashlytics pipe leaves untouched. A future Tier 3 routine (Sprint 17+) will fill them via the Anthropic API. Don't repurpose those columns until that ships.
