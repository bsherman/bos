# 0002 — Agent-portable instruction surface

- **Status:** Accepted
- **Date:** 2026-08-06

## Context

The project is maintained by whichever coding agent is available — each tool
reads its own instruction file (`CLAUDE.md`, `.github/copilot-instructions.md`,
`GEMINI.md`, `AGENTS.md`) and its own skills location (`.claude/skills/`).
Duplicating conventions per tool guarantees drift, and drift means different
agents follow different law.

## Decision

One canonical surface, tool paths as symlinks:

- **`AGENTS.md`** (the emerging cross-tool standard) is the real file holding
  all conventions. `CLAUDE.md`, `GEMINI.md`, and
  `.github/copilot-instructions.md` are symlinks to it.
- **`.agents/skills/`** is the real skills directory (`<skill>/SKILL.md` with
  YAML frontmatter). `.claude/skills` is a symlink to it.
- Content is written tool-agnostically: plain markdown, no tool-specific
  directives; anything only one tool understands stays out of the shared
  files.

## Consequences

- Conventions and skills are edited in exactly one place; every agent sees
  the same law.
- Symlinks are committed to git — fine on Linux/macOS; GitHub's web renderer
  may show link targets rather than content, an accepted cosmetic cost.
  Native Windows checkouts need `core.symlinks=true` or WSL.
- The skill format is the lowest common denominator (frontmatter + markdown
  steps); agents without native skill support are pointed at the directory
  from AGENTS.md.
- The starter template is stored as `.agents/skills/TEMPLATE/SKILL.md.txt`,
  not `SKILL.md` — a deliberate deviation from upstream agentic-template.
  Skill discovery enumerates every `<dir>/SKILL.md` under `.claude/skills`,
  so an upstream-named template would load in every session as a junk skill
  (its placeholder frontmatter declares `name: skill-name`, which also
  disagrees with its directory). Copy it to `<name>/SKILL.md` when writing a
  real skill.
- `AGENTS.md`/`CLAUDE.md` were previously gitignored in this repo (personal,
  local-only agent config); this ADR reverses that — they are now committed
  and canonical, and `.gitignore` no longer excludes them.
  `.claude/settings.local.json` stays ignored (it is listed in the repo's own
  `.gitignore`) since it holds machine-local tool permissions, not project
  conventions.

## Alternatives considered

- **Per-tool copies kept in sync by convention:** guaranteed drift. Rejected.
- **Instructions for one tool only:** wastes every other agent exactly when
  it's needed. Rejected.
- **Keep `AGENTS.md` gitignored/local-only:** this repo's prior convention;
  keeps agent instructions out of the shared history, but means every
  contributor (human or agent) starts from zero and conventions aren't
  reviewable in PRs. Rejected in favor of the canonical, committed surface.

## References

- Builds on: [ADR-0001](0001-record-architecture-decisions.md)
- Shapes: `AGENTS.md`, [.agents/skills/](../../.agents/skills/)
