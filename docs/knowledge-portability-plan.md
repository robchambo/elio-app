# Plan: Make Elio Knowledge Portable Across Devices and Sessions

## Context

The user has built most of Elio within a single long-running Claude Code conversation. That conversation accumulated deep working knowledge — Flutter gotchas, build workflows, architecture decisions, bug fixes, Gemini prompt tuning — that makes each interaction fast and accurate. When opening Claude Code on a different device (laptop), the quality drops: wrong file structures, slower builds, more bugs.

**Root cause:** Three layers carry knowledge into a Claude Code session, and only one of them is truly portable right now.

| Layer | What it is | Portable across devices? | Currently complete? |
|-------|-----------|-------------------------|-------------------|
| **CLAUDE.md** (repo root) | Project instructions loaded into EVERY session that opens this repo | YES — travels with git | Partial — has rules + gotchas but missing a lot |
| **Memory files** (`~/.claude/projects/.../memory/`) | User-scoped persistent memory | NO — path is machine-specific | Good content, but trapped on this machine |
| **docs/** (repo) | Technical design, product guide, roadmap | YES — travels with git | Good, but Claude doesn't auto-read them |
| **Conversation context** | Everything we've discussed | NO — dies with the session | This is where most knowledge actually lives |

**The fix:** Move everything load-bearing into `CLAUDE.md`. It's the ONLY file guaranteed to be loaded automatically in every Claude Code session on every device. Memory files are a supplement but are machine-bound.

---

## What to Do

### 1. Rewrite CLAUDE.md as the definitive knowledge base

The current CLAUDE.md is ~70 lines. It needs to become the single source of truth. Structure:

```
# Elio — AI Recipe Generator
## Identity (what, who, stack, repo)
## Build — CRITICAL (build.ps1, never raw flutter build, .env.local)
## Rules (the 9 numbered rules — keep as-is, they're good)
## Flutter Gotchas (keep + expand from conversation learnings)
## Architecture Quick Reference (from memory/project_elio_architecture.md)
## Gemini API (current config, prompt patterns, what NOT to change)
## Design System (tokens, fonts, shape language)
## Monetisation (freemium model, paywall logic, dry-mode behaviour)
## Known Issues (from memory/project_elio_critical_issues.md)
## Current Sprint Status (what's done, what needs testing)
## Docs Pointers (where to find detailed info in docs/)
```

Key content to migrate in from memory files and conversation:

- **Architecture** (from `project_elio_architecture.md`): directory structure, Firestore schema, design tokens
- **Build safety** (from `feedback_build_safety.md`): build.ps1 mandatory, Gemini config state, dev account testing
- **Agent workflow** (from `feedback_agent_workflow.md`): when to use single vs multi-agent, worktree merge safety
- **Paywall dry-mode** (from `feedback_paywall_dry_mode.md`): optimistic trial display when RC packages empty
- **Critical issues** (from `project_elio_critical_issues.md`): RC not wired, ErrorService thin, stale tests
- **Monetisation model**: pricing, tiers, trial mechanics
- **Gemini prompt patterns**: what's required vs optional in the prompt, current model config

### 2. Keep memory files as-is (don't delete)

Memory files still help on the original machine. They provide additional context. But they should no longer be the ONLY place critical knowledge lives. CLAUDE.md becomes the canonical copy; memory files become supplementary.

### 3. Add doc-reading instructions to CLAUDE.md

Add a table telling Claude which files to read before editing specific areas:

- Touching paywall/monetisation → read `docs/technical-design.md` Section 9
- Touching Gemini prompts → read `lib/services/gemini_service.dart` header
- Planning sprint work → read `docs/roadmap.md`
- Changing onboarding → read `docs/product-guide.md` onboarding section

### 4. Update the "Last Session" block

This block is already a good pattern. Keep it — updated each session with the current sprint, what was done, and what needs testing.

---

## Files Modified

| File | Action |
|------|--------|
| `CLAUDE.md` | Major rewrite — expanded from ~70 lines to comprehensive knowledge base (~215 lines) |
| `docs/claude-portability-guide.md` | New file — sharable guide explaining the system, prompts for different collaborator types, and maintenance instructions |

---

## Verification

1. Read the final CLAUDE.md end-to-end to confirm nothing load-bearing is missing
2. Cross-check against each memory file to ensure all critical content is captured
3. Test by opening a NEW Claude Code session on the same or a different device, pointing at the Elio repo — the session should "know" the rules, architecture, and current status without being told anything beyond the repo path

---

## Outcome

CLAUDE.md is now the single source of truth for any Claude Code session on any device. It contains everything a session needs to work at full quality: build process, rules, gotchas, architecture, Gemini config, design system, monetisation logic, known issues, and current sprint status. It travels with the git repo, so pulling on any machine gives full context immediately.

Memory files remain as supplementary context on the original machine but are no longer the only place critical knowledge lives.
