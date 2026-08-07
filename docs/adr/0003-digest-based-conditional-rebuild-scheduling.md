# 0003 — Digest-based conditional rebuild scheduling

- **Status:** Accepted
- **Date:** 2026-08-06

## Context

Desktop and server builds run on a daily schedule (`cron: "41 6 * * *"`) across
every enabled image variant in `images.yaml`. Most upstream Bazzite/uCore base
images do not change every day, so rebuilding, re-chunking, and re-signing
every variant on every scheduled run burns CI minutes and produces image
churn (new signed digests, changelog noise) for images whose content did not
actually change upstream. Scheduled runs need a cheap, reliable way to decide
*before* building whether a variant's upstream base has moved since the last
published, signed build — without a separate state store, since CI runners
are stateless between runs and the only durable record of "what did we last
build" is the published image itself.

## Decision

`just generate-ci-matrix <flavor> <changed_only>` decides the build matrix:

- For each CI-enabled variant, resolve the upstream base image's exact
  manifest digest via `skopeo inspect --raw` (hashed, not the mutable tag).
- When `changed_only=true` (scheduled runs only), compare that resolved
  digest against the `org.opencontainers.image.base.digest` label already
  recorded on the currently published, signed image for that tag, per
  architecture. A variant is included in the matrix only if the label differs,
  the published image/label is missing (new variant, or first run after this
  mechanism shipped), or `cosign verify` on the currently published image
  fails (fail toward rebuilding, not toward silently trusting an
  unverifiable image).
- Pull requests always set `changed_only=false` — every enabled variant
  builds for validation — but never publish. Merges to `main` always publish
  every enabled variant that built, regardless of digest state.
- The digest resolved at matrix-generation time is threaded through as the
  `base_digest` build argument (`just build <image> <base_digest>`), so the
  image that gets built and labeled is pinned to the exact digest the matrix
  decision was based on — not a possibly-newer tag resolved again at build
  time. `build-image.yml`'s "Verify upstream base metadata" step asserts the
  built image's label matches what the matrix selected.

## Consequences

- Scheduled runs skip variants with unchanged upstream bases, cutting daily
  CI time/cost roughly in proportion to how many variants are actually
  stable day to day.
- The first scheduled run after this mechanism was introduced rebuilds every
  enabled variant, since existing published images predate the
  `base.digest` label.
- A transient `skopeo` failure resolving the *upstream* digest fails the
  matrix-generation job outright (retried 3x with backoff). Failures against
  the *published* image split two ways: a `cosign verify` failure is treated
  as "needs rebuild", but a `skopeo inspect` failure whose error doesn't look
  like "image absent" aborts matrix generation for the whole flavor.
- New variants added to `images.yaml` are built automatically on their first
  scheduled run, since a missing published image/label is treated as
  "changed."
- Adds a runtime dependency on `skopeo` and `cosign` being available wherever
  `generate-ci-matrix` runs (already required for local builds per
  [AGENTS.md](../../AGENTS.md)).

## Alternatives considered

- **Rebuild every enabled variant on every scheduled run:** simplest, but was
  the status quo problem — wasted CI time and produced unnecessary signed
  image churn on unchanged variants. Rejected.
- **Time-based staggered scheduling (e.g. rotate which variants build each
  day):** doesn't track whether anything actually changed, so still rebuilds
  unnecessarily on some days and can delay picking up a real upstream
  security update on others. Rejected.
- **External change-tracking (webhook/API from upstream ublue-os projects):**
  no such notification mechanism is published by the upstream image
  projects. Rejected as impractical.

## References

- Shapes: [docs/design/build-scheduling.md](../design/build-scheduling.md)
- Builds on: none (first project-specific ADR)
