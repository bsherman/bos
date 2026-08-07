# Spec: Thing Being Specified (e.g. a file format, CLI, endpoint)

<!--
Specs are precise, testable contracts. They change only alongside the code
that implements them. Use MUST/SHOULD/MAY deliberately. If a requirement can't
be checked mechanically or by a clear manual test, it belongs in a design doc
instead.
-->

One paragraph: what this contract governs and who consumes it (code, agents,
the CLI, other services).

## Interface

The exact shape — fields, commands, endpoints. Prefer tables for fields and
fenced examples for formats:

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `name` | string | yes | … |

```toml
# minimal valid example
```

## Rules

Numbered or bulleted invariants, each independently checkable:

- `slug` is immutable after creation.
- Re-running any command converges to the same state (idempotence).

## Derived artifacts

<!-- If other things are generated from this contract, list them so a change
here is understood to ripple. Delete the section if not applicable. -->

| Artifact | Derivation |
| --- | --- |

## References

<!-- Required. Every spec links: the ADR(s) that motivated it and the design
doc that shows where it fits. -->

- Rationale: [ADR-NNNN](../adr/NNNN-….md)
- Context: [design/…](../design/….md)
