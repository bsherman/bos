# bOS

Personal Universal Blue-derived OCI image builds, published as a single image
name `bos` with multiple tags (Bazzite desktop variants, uCore server
variants). Start at [docs/README.md](docs/README.md) for the full docs index.

This file (`AGENTS.md`) is the CANONICAL agent instructions — `CLAUDE.md`,
`GEMINI.md`, and `.github/copilot-instructions.md` are symlinks to it, and
`.claude/skills` symlinks to `.agents/skills/`
([ADR-0002](docs/adr/0002-agent-portable-instruction-surface.md)). Edit only
the canonical paths; keep content tool-agnostic.

## Skills (follow these for common tasks)

Step-by-step procedures live in [.agents/skills/](.agents/skills/); follow
them rather than improvising, whichever agent you are:

- *(none yet — add the first one when a procedure repeats)*

Start a new skill by copying `.agents/skills/TEMPLATE/SKILL.md.txt` to
`.agents/skills/<name>/SKILL.md` (the template keeps a `.txt` extension so it
is not itself discovered as a skill), then register it with a bullet above.

## Project structure & module organization

The root contains the primary build surface: `Containerfile`, `Justfile`,
`build.sh`, and `images.yaml` (the single source of truth for all image
variants, their upstream bases, multi-arch status, CI enablement, and build
metadata such as `base_tag`). Build scripts live in `build_scripts/` (e.g.
`desktop-packages.sh`, `server-packages.sh`, `shared-changes.sh`, etc.).
Configuration overlays live in `system_files/`, grouped by image family, for
example `system_files/shared/` and `system_files/sysext/`. GitHub Actions
workflows are in `.github/workflows/`, with reusable local actions in
`.github/actions/`. There is no application source tree or conventional test
directory; validation is driven by linting, recipe checks, and image builds.

## Build, test, and development commands

Use `just --list` to see available recipes. Common commands:

- `just build bazzite` builds a local `localhost/bos:bazzite` image.
- `just build ucore` builds a server image variant.
- `just generate-ci-matrix Server true` shows changed server variants selected
  for a scheduled CI build.
- `just lint` runs shell, YAML, Justfile, and generated recipe lint checks.
- `just format` applies `shfmt`, `yamlfmt`, and Justfile formatting.
- `just check` verifies Justfile syntax without rewriting files.
- `just clean` removes generated image/changelog artifacts from local builds.

Local builds require Podman or Docker plus tools used by the recipes,
including `just`, `skopeo`, `jq`, `cosign`, `shellcheck`, `shfmt`, `yamllint`,
and `yamlfmt`.

## Code conventions (live — the code exists)

- Shell scripts use Bash with `set -eou pipefail` where practical.
- Follow `.editorconfig`: four-space indentation for `*.sh`, LF line endings,
  final newlines, trimmed trailing whitespace, and an 80-column target. Keep
  scripts executable when they are meant to run directly.
- Prefer descriptive variant names matching image tags, such as
  `bazzite-gnome-nvidia` or `ucore-hci-lts`.
- `images.yaml` is the single source of truth for image variants — add or
  change a variant there, not by hardcoding tags in scripts or workflows.
- Run `just lint` (shell, YAML, Justfile, and generated-recipe lint) before
  calling any change done. `.github/workflows/lint.yml` runs the same recipe
  on every push and PR, so a local pass is a CI pass.

## Repository boundary

There is no application source tree or conventional test directory in this
repo; it only builds and configures OCI images. Do not commit private signing
keys (`cosign.key`), registry tokens, or other generated secrets. Do not
commit generated build artifacts (`bos_*`, `version.txt`, `changelog*.md`,
`output*.env`) — these are build outputs, not source. Published images are
signed with Cosign; keep `cosign.pub` public and store private signing
material only in GitHub Actions secrets.

## Documentation rules (enforced)

Docs live in `docs/` in four categories. **Every new doc starts from its
category's `TEMPLATE.md`** and follows its structure:

- `docs/adr/` — why we decided. Immutable once Accepted; reversals are new
  ADRs that mark the old one Superseded.
- `docs/design/` — how it fits together. Living; updated in place to match
  reality.
- `docs/specs/` — exact contracts. Change only alongside implementing code.
- `docs/plans/` — order of work. Phases with "Done when" outcomes.

### Cross-linking is mandatory

A doc without its required links is incomplete — do not finish a docs change
until they exist, in both directions:

- **ADR** → links every design doc/spec it shapes, and prior ADRs it builds on.
- **Design doc** → links the ADR(s) providing its rationale, the spec(s)
  pinning its contracts, and the roadmap phase that builds it.
- **Spec** → links its motivating ADR(s) and the design doc showing where it
  fits.
- **Plan** → every phase links the design docs/specs it implements; resolved
  open questions become ADRs.

When you touch a doc, verify its links still hold (targets exist, section
anchors valid) and add the back-links on the targets. Use relative paths.

### Housekeeping

- New doc ⇒ add a line to the index in [docs/README.md](docs/README.md).
- New significant decision ⇒ new ADR *first*, then update the affected design
  docs/specs in the same change.
- Convert relative dates ("next weekend") to absolute dates in all docs.

## Testing guidelines

Run `just lint` before submitting changes. For build logic changes, also run
at least one representative local build, for example `just build bazzite` for
desktop changes or `just build ucore` for server changes. When changing
`system_files/`, choose the image variant that consumes that overlay.

## Commit & pull request guidelines

Recent history uses Conventional Commit-style subjects such as `feat: add
zellij` and `chore(deps): bump ...`. Keep commit titles concise and
imperative. The repository enables semantic PR title checks, so PR titles
should follow the same pattern. PRs should describe the affected image
variants, list validation performed, and include relevant build or lint
output when changing build, packaging, signing, or workflow behavior.
