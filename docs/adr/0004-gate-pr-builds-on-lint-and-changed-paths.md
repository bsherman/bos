# 0004 — Gate PR builds on lint and changed paths

- **Status:** Accepted
- **Date:** 2026-08-07

## Context

On `pull_request` to `main`, `lint.yml`, `build-desktop.yml`, and
`build-server.yml` currently trigger independently and run in parallel.
Lint (shellcheck/yamllint/Justfile checks) typically finishes in well under
a minute; `build-desktop.yml`/`build-server.yml` each `uses:` the reusable
`build-image.yml` workflow to build every enabled multi-arch image variant
for validation (per ADR-0003, PRs always set `changed_only=false`), which
can run for many minutes across several runners. A PR with a trivial shell
syntax error still pays for the full expensive build, since nothing
coordinates the three workflows. Separately, `build-desktop.yml`/
`build-server.yml` already skip themselves for docs-only PRs via a
`paths-ignore` list on their `pull_request` trigger, but that only works as
a trigger-level filter — it can't be preserved as-is once the build
workflows stop declaring their own `pull_request` trigger.

## Decision

A new `.github/workflows/pr-checks.yml` becomes the sole entry point for
`pull_request` events targeting `main`. It runs:

- `lint`: calls `lint.yml` via `workflow_call`.
- `changes`: checks out full history and diffs the PR's base/head SHAs,
  checking each changed file against an ignore-pattern list that mirrors
  `build-desktop.yml`/`build-server.yml`'s existing push-trigger
  `paths-ignore` list, via an inline bash step (no third-party action).
  Emits a `relevant` boolean job output.
- `build-desktop` / `build-server`: each `needs: [lint, changes]`, gated on
  `if: success() && needs.changes.outputs.relevant == 'true'` — the
  explicit `success()` is required because adding any custom `if:` to a job
  with `needs:` replaces GitHub's implicit "all needed jobs succeeded"
  check, so a lint failure would not otherwise actually block the build.

`build-desktop.yml` and `build-server.yml` drop their own `pull_request`
trigger entirely; they retain `schedule`, `push` (with its existing
`paths-ignore`), `workflow_call`, and `workflow_dispatch` unchanged. `push`
to `main`, `schedule`, and `workflow_dispatch` runs are therefore completely
unaffected — only the `pull_request` path is restructured.

`pr-checks.yml` declares `permissions: {contents: write, packages: write,
id-token: write}` at its top level, matching exactly what
`build-desktop.yml`/`build-server.yml` already declare for their own direct
triggers. This looks broader than what a PR run actually exercises —
`packages: write`/`id-token: write` only matter inside `build-image`'s
"Push to GHCR" step and `create-manifest`, both gated on
`needs.get-images.outputs.publish == 'true'`, and `publish` is always
`false` for PR-triggered runs. But GitHub validates a `uses:` call against
the *full* top-level `permissions:` block the called reusable workflow
declares, not just the subset its currently-reachable steps happen to use —
a caller granting anything less fails immediately at dispatch time (`The
workflow is requesting '...', but is only allowed '...'`), before any job
runs. A narrower grant (`contents: read, packages: read` — matching what
`get-images`'s unconditional GHCR login and digest-inspection steps
actually need) was tried and rejected for exactly this reason: it satisfies
every step PR runs actually reach, but not the static permission check
GitHub performs against `build-desktop.yml`/`build-server.yml`'s declared
requirement.

`lint.yml` no longer declares its own top-level `concurrency:` block.
Inside a called reusable workflow, `github.workflow` resolves to the
*caller's* name, not the callee's — so `lint.yml`'s former group
(`${{ github.workflow }}-${{ github.ref || github.run_id }}`) resolved to
`PR Checks-<ref>` when invoked from `pr-checks.yml`, identical to
`pr-checks.yml`'s own top-level concurrency group. The parent run held that
group while trying to queue its own `lint` job into it, which GitHub
detected as an unresolvable deadlock and canceled. The block's original
purpose — canceling superseded runs on rapid PR pushes via
`cancel-in-progress: ${{ github.event_name == 'pull_request' }}` — is moot
now that `lint.yml` is never directly `pull_request`-triggered; that
condition can't be true on its remaining direct triggers (`push`,
`workflow_dispatch`). `pr-checks.yml`'s own top-level concurrency group
already covers cancellation for the PR path.

## Consequences

- A failing lint step now prevents the expensive multi-arch build from
  running at all on a PR, cutting CI time and time-to-signal on trivial
  errors.
- Docs-only / ignored-path PRs still skip the expensive build, matching
  today's behavior, but the build jobs now appear as **skipped** entries in
  the PR's checks list rather than not appearing at all (today's
  trigger-level `paths-ignore` means the workflow simply never runs). Minor
  visibility change, not a functional regression.
- The build-relevance ignore list now exists in two hand-maintained places:
  the YAML `paths-ignore` on `build-desktop.yml`'s/`build-server.yml`'s
  `push` trigger, and the bash `ignore_patterns` array in `pr-checks.yml`'s
  `changes` job. No automated check enforces they match — see
  `docs/design/build-scheduling.md` Operational notes.
- Effective `GITHUB_TOKEN` permissions on PR runs match the full
  `contents: write, packages: write, id-token: write` grant
  `build-desktop.yml`/`build-server.yml` already use for push/schedule
  runs, even though PR runs never exercise the write/OIDC scopes
  (`publish` is always `false`). This is required by GitHub's static
  permission check on `uses:` calls, not by anything a PR run actually
  does — see Decision.
- `push`/`schedule`/`workflow_dispatch` triggers, and everything inside
  `build-image.yml`, are untouched.

## Alternatives considered

- **`workflow_run`-based gating** (have `build-desktop.yml`/
  `build-server.yml` trigger off `lint.yml`'s completion via
  `workflow_run`): rejected — adds indirection, doesn't attach cleanly to
  the PR's head SHA without extra Checks API bookkeeping, jobs don't show
  as pending in the PR checks list until lint finishes, and it still
  wouldn't solve the docs-only-PR path-filtering problem on its own.
- **`dorny/paths-filter` (or similar third-party action):** rejected in
  favor of an inline `git diff` step, to avoid adding a third-party action
  to a workflow chain that already carries publish-capable permissions and
  signing secrets, and to keep the mirrored ignore-list logic inline,
  auditable, and consistent with the rest of the repo's hand-written bash.
- **Dropping the path-filter optimization** (always run the full build
  regardless of changed paths): rejected — would regress from today's
  behavior, wasting more CI time, not less.

## References

- Shapes: [docs/design/build-scheduling.md](../design/build-scheduling.md)
- Builds on: [ADR-0003](0003-digest-based-conditional-rebuild-scheduling.md)
