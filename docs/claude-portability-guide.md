# Claude Code Portability Guide — Elio

**Date:** 11 April 2026 | **Purpose:** Ensure any Claude Code session on any device has full project context

---

## The Problem

Knowledge accumulates inside a single Claude Code conversation window. When you open a new session on a different device, the quality drops — wrong file structures, slower builds, more bugs — because the knowledge didn't transfer.

## How Claude Code Sessions Get Context

There are three layers, and only two are portable:

| Layer | What it is | Portable? | Notes |
|-------|-----------|-----------|-------|
| **CLAUDE.md** (repo root) | Project instructions | Yes — travels with git | Loaded automatically in every session |
| **Memory files** (`~/.claude/projects/.../memory/`) | User-scoped persistent memory | No — machine + user specific | Supplements CLAUDE.md on the original machine |
| **Conversation context** | Everything discussed in a session | No — dies with the session | The biggest knowledge source, the least portable |

## The Solution

**CLAUDE.md is the single source of truth.** It now contains everything load-bearing:

- Project identity, stack, repo
- Build process (build.ps1 mandatory, never raw flutter build)
- 9 project rules
- Flutter gotchas (hard-won bug avoidance)
- Full architecture reference (directory tree, Firestore schema)
- Gemini API config and prompt structure
- Design system tokens
- Monetisation model and paywall logic (including dry-mode rule)
- Agent workflow patterns
- All known issues
- Launch strategy
- Doc pointers (which file to read before editing which area)
- Last session status

**Any Claude Code session that opens this repo will automatically read CLAUDE.md and have full context.**

## Files NOT in Git (must share manually)

| File | What it is | Who needs it |
|------|-----------|--------------|
| `.env.local` | Contains `GEMINI_API_KEY` | Anyone building the app |
| `google-services.json` | Firebase config (goes in `android/app/`) | Anyone building the app |

Share these securely (not via email/Slack in plaintext). They're in `.gitignore` for a reason.

## Prompts

### For Rob (primary developer, any device)

```
I'm working on Elio, an AI recipe generator Flutter app.

Clone (if not already):
  git clone https://github.com/robchambo/elio-app.git
  cd elio-app

Everything you need is in CLAUDE.md at the repo root — read it in full
before doing anything. It has the build process, rules, architecture,
Gemini config, design system, monetisation, known issues, and current
sprint status.

Current sprint: 15.3.20. Pick up from the "Last Session" and
"Needs Testing" sections in CLAUDE.md.
```

### For a collaborator (e.g., Kate — brand/art)

```
I'm collaborating on Elio, an AI recipe generator Flutter app.

Repo: https://github.com/robchambo/elio-app (you need collaborator
access — ask Rob if you haven't been added).

Start by reading these files:
  1. CLAUDE.md — project overview, rules, architecture (read the
     Identity, Design System, and Monetisation sections)
  2. docs/brand-art-concept.md — the brand/art brief
  3. docs/product-guide.md — what the app does, feature by feature

The design system tokens already in the app:
  Navy #1A2744 | Amber #F08C14 | Sky #4A90D9 | Off-white #F7F5F2
  Headings: Outfit | Body: Quicksand

I'm here to work on [describe task — e.g., logo concepts, illustration
style, app icon, onboarding art, paywall art].
```

### For a collaborator (developer)

```
I'm collaborating on Elio, an AI recipe generator Flutter app.

Clone:
  git clone https://github.com/robchambo/elio-app.git
  cd elio-app

Read CLAUDE.md in full before doing anything — it's the complete
project reference. Pay special attention to:
  - "Build — CRITICAL" (you MUST use build.ps1, never raw flutter build)
  - "Rules" (especially commit/analyze/tag workflow)
  - "Flutter Gotchas" (these will save you hours)
  - "Known Issues" (things that are broken and why)

You'll also need two files not in git (get from Rob):
  - .env.local (Gemini API key)
  - android/app/google-services.json (Firebase config)

Current sprint: 15.3.20. Check "Last Session" in CLAUDE.md for status.
```

## Maintenance

Keep CLAUDE.md updated as the project evolves:

- **After every session:** Update the "Last Session" block with what was done, what needs testing, and current sprint number
- **After discovering a new gotcha:** Add it to "Flutter Gotchas"
- **After fixing a known issue:** Remove it from "Known Issues"
- **After a sprint milestone:** Update "Launch Strategy" and sprint status
- **After changing Gemini config:** Update "Gemini API" section and "Gemini API State"

The memory files on the original machine will continue to provide supplementary context, but they should never be the ONLY place critical knowledge lives. CLAUDE.md is canonical.
