# Notes on the former `"keep"` behavior

`"keep"` support for `incomplete_dyads` and `missing_role` was removed before
the first CRAN-oriented API. It may be useful later for exploratory workflows,
but it created ambiguous model-ready columns for unknown dyad compositions.

## Previous validation behavior

- `incomplete_dyads = "keep"` retained dyads with only one observed member.
  - It warned with `"Keeping ... incomplete dyad(s) ... Composition labels may
    be unknown."`
  - It stored those group IDs in `attr(data, "interdep")$incomplete_dyads`.
- `missing_role = "keep"` retained dyads where at least one member had no known
  role.
  - It warned with `"Keeping ... dyad(s) with incomplete role information ..."`
  - It replaced unresolved roles with the label `"unknown"` before composition
    inference.
- If `missing_role = "drop"` removed an incomplete dyad that had previously
  been kept, validation filtered `incomplete_dyads` metadata to groups still
  present in the data.

## Previous composition behavior

- Incomplete dyads received one synthetic `"unknown"` role during composition
  inference.
  - Example: one observed female member became `female_x_unknown`.
- Dyads with at least one `"unknown"` role were assigned `dyad_type = "unknown"`.
- Unknown dyads used row-level composition-role labels.
  - Example: `female_x_unknown_female`
  - Example: `female_x_unknown_unknown`

## Tests that covered the old behavior

- Validation:
  - incomplete dyads with `incomplete_dyads = "keep"`
  - metadata alignment after keeping incomplete dyads and dropping missing roles
  - missing roles with `missing_role = "keep"`
- Preparation:
  - retained unknown roles in compositions
  - retained incomplete dyads in compositions
- Arbitrary roles:
  - retained incomplete dyads
  - unknown dyads using arbitrary-role model columns

## Reimplementation notes

If `"keep"` is reintroduced, decide the modeling contract first:

- whether unknown dyads are model-ready or inspection-only
- whether `unknown` dyads should use observed/unknown role labels or arbitrary
  role labels
- whether incomplete dyads with only one observed member may contribute to model
  terms
- how unknown rows interact with future constrained or pooled compositions

Implementation points to restore:

- add `"keep"` back to `incomplete_dyads` and/or `missing_role` argument choices
- restore the keep branches in `resolve_incomplete_dyads()` and
  `resolve_interdep_roles()`
- restore `interdep_unknown_label` if it has been removed
- restore synthetic unknown-role handling in `infer_dyad_compositions()`
- restore tests for retained incomplete dyads and missing roles
