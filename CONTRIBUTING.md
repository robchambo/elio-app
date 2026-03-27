# Contributing to Elio

## Branching

| Branch type | Naming | Example |
|---|---|---|
| Feature | `feature/<short-description>` | `feature/google-sign-in-fix` |
| Bug fix | `fix/<short-description>` | `fix/guest-pantry-persistence` |
| Chore / tooling | `chore/<short-description>` | `chore/upgrade-gradle` |

- **Never commit directly to `main`**
- Create a branch, open a PR, merge via GitHub
- One concern per PR — fixes separate from features

## Commits

Keep messages concise and factual:

```
fix: guest pantry not persisting across sessions

Short explanation of why if not obvious.
```

Prefixes: `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`

## Pull Requests

- Target branch: `main`
- Title should match the commit prefix convention
- CI (`flutter analyze`) must pass before merging

## Secrets

Never commit:
- `google-services.json`
- `GoogleService-Info.plist`
- `lib/firebase_options.dart`
- Any file containing API keys

These are all gitignored. If you need to add a new secret, add it to `.gitignore` first.
