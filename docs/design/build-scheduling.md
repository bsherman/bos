# Build scheduling

Living document. Rationale:
[ADR-0003](../adr/0003-digest-based-conditional-rebuild-scheduling.md),
[ADR-0004](../adr/0004-gate-pr-builds-on-lint-and-changed-paths.md).

## Overview

Scheduled CI builds for bos's desktop and server image variants compare each
variant's upstream base image digest against the digest recorded on the
currently published, signed image before deciding what to build, so unchanged
variants are skipped on daily scheduled runs.

```
schedule/push ──────────────────────────────────┐
                                                  │
pull_request ──► pr-checks.yml                   │
                    ├─ lint                       │
                    └─ changes ──── (gated) ──────┤
                                                  ▼
                                    get-images (just generate-ci-matrix)
                                                  │
                                                  ▼
                                    build-image (matrix: image × arch)
                                                  │
                                                  ▼
                                    create-manifest (multi-arch manifest,
                                                       sign, push)
```

## Design

`.github/workflows/build-desktop.yml` and `build-server.yml` both call the
reusable `build-image.yml` workflow with an `image_flavor` (`Bazzite` /
`Server`), on a daily `schedule`, on `push` to `main`, on `workflow_call`
(invoked by `pr-checks.yml` for pull requests — see below), and on
`workflow_dispatch`. Neither declares its own `pull_request` trigger;
`.github/workflows/pr-checks.yml` is the sole entry point for
`pull_request` events targeting `main`
([ADR-0004](../adr/0004-gate-pr-builds-on-lint-and-changed-paths.md)).

**Pull request gating** — `pr-checks.yml` runs `lint` (a `workflow_call` to
`lint.yml`) and `changes` (an inline `git diff` against the PR's base/head
SHAs, checked against an ignore-pattern list mirroring
`build-desktop.yml`/`build-server.yml`'s `push.paths-ignore`) in parallel,
then runs `build-desktop`/`build-server` only if lint succeeded and
`changes` found at least one non-ignored path. A PR touching only files
covered by the ignore list never triggers a build; a PR with a lint failure
never triggers a build either, regardless of what files changed.

**`get-images` job** runs `just generate-ci-matrix <flavor> <changed_only>`
(`changed_only=true` only on `schedule` events):

- `upstream_digest()` resolves each distinct `<base_image>:<base_tag>` pair's
  exact manifest digest via `skopeo inspect --raw`, hashed with `sha256sum`,
  and caches it per-key so variants sharing a base are only inspected once.
- `variant_needs_rebuild()` checks, per architecture, whether the published
  image's `org.opencontainers.image.base.digest` label matches the resolved
  upstream digest. A missing/unpublished image (`manifest unknown`, `name
  unknown`, `not found`, 404) is treated as needing a build — this is what
  makes new variants build automatically on their first scheduled run. If the
  label matches on every architecture, it falls back to `cosign verify` on
  the published image; a verification failure is also treated as needing a
  rebuild.
- The matrix job emits `images` (flat list of `{image, arch, runner,
  base_digest}`) and `manifest_images` (grouped by image, for the later
  multi-arch manifest step), plus `publish` (`true` except on `pull_request`).

**`build-image` job** runs `just build <image> <base_digest>` per matrix
entry, pinning the build to the exact digest the matrix already resolved
(not re-resolving the tag, which could have moved). It labels the built image
with `org.opencontainers.image.base.digest=<base_digest>` and a "Verify
upstream base metadata" step asserts the built image's label matches what was
passed in, before pushing per-arch tags.

**`create-manifest` job** (publish runs only) assembles the per-arch tags into
a multi-arch manifest per image, pushes it under both the flavor tag and the
resolved version tag, and signs both with Cosign.

## Operational notes

- The PR-time ignore list in `pr-checks.yml`'s `changes` job and the
  push-time `paths-ignore` on `build-desktop.yml`/`build-server.yml` are two
  independent, hand-maintained copies of the same list — if a PR's build
  unexpectedly does or doesn't skip, check both for drift.
- The first scheduled run after this mechanism shipped rebuilds every enabled
  variant, since existing published images predate the `base.digest` label.
- `pull_request` runs always set `changed_only=false` (build everything,
  validate, never publish) so PRs get full build coverage regardless of
  upstream digest state.
- Pushes to `main` always publish every enabled variant that built,
  regardless of digest state — publishing is driven by the git event, not by
  whether a rebuild was "needed."
- To debug why a variant was or wasn't selected on a scheduled run, check the
  "Get Images for Build" job's log output from `just generate-ci-matrix`
  (`stderr` prints `Skipping <tag>; <base>:<tag> is unchanged` for skipped
  variants).
- `skopeo` transient failures resolving the *upstream* digest retry 3x with
  backoff before failing the job (`cosign` is not involved in upstream digest
  resolution — it only ever runs against published images).
- A `cosign verify` failure on the *published* image is non-fatal and instead
  forces a rebuild.
- But a `skopeo inspect` failure on the *published* image is fatal to the
  whole flavor: `variant_needs_rebuild()` only treats the error as "image
  absent, build it" when stderr matches `manifest unknown|name unknown|not
  found|no image found|status code: 404`. Anything else (registry 5xx, auth
  blip, rate limit) returns `2` after 3 retries, and the caller does
  `exit "${status}"` — so one bad published tag aborts matrix generation for
  every variant in that flavor, not just its own. This is the failure mode to
  suspect when a scheduled run dies in "Get Images for Build" with no matrix
  emitted.

## References

- Rationale: [ADR-0003](../adr/0003-digest-based-conditional-rebuild-scheduling.md),
  [ADR-0004](../adr/0004-gate-pr-builds-on-lint-and-changed-paths.md)
- Built in: already shipped (PR #43 and follow-ups); not tracked in a
  `docs/plans/` roadmap retroactively.
