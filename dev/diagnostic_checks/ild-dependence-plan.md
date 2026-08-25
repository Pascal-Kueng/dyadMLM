# Provisional ILD Dependence Profile

Status: future milestone. Gaussian same-occasion pairing in
`check_partner_dependence()` comes first.

The eventual ILD check should localize observable dependence without creating
separate public functions for stable, concurrent, own-lag, and cross-lag
features:

```r
check_ild_dependence(
  simulations,
  dyad,
  member,
  time,
  role = NULL,
  lags = NULL
)
```

It uses model-centred responses. Resolve identifiers like the partner check,
require at most one row per dyad-member-time combination, retain exact missing
gaps, and use one common set of dyads across panels.

## Between/within decomposition

For every observed and replicated complete dataset, calculate

\[
B_{jm}=\operatorname{mean}_t(z_{jmt}), \qquad
W_{jmt}=z_{jmt}-B_{jm}.
\]

These are observable finite-series summaries, not latent effects. Repeating the
same decomposition in every replicate carries finite-series demeaning, missing
occasions, and the fitted dependence structure into the comparison.

The default display has two panels:

1. a replicated histogram for stable partner association between the member-
   series means; and
2. an observed within-series lag profile over pointwise 50% and 95% simulation
   envelopes.

For stable dependence, let \(u=B_{j1}\) and \(v=B_{j2}\). For lag zero, let
\(u=W_{j1t}\) and \(v=W_{j2t}\) over complete dyad-occasion pairs.

When roles are supplied, orient pairs by role and use ordinary role-specific
SDs and Pearson partner correlation. Report a separate positive-lag own-member
curve for each role and both directed cross-partner curves.

When roles are absent, never correlate arbitrary member-position columns for
the stable or lag-zero statistic. Reuse the exchangeable reconstruction:

\[
M=(u+v)/2, \qquad D=(u-v)/2,
\]

\[
\widehat v=s_M^2+s_{D0}^2, \qquad
\widehat c=s_M^2-s_{D0}^2, \qquad
\widehat\rho=\widehat c/\widehat v.
\]

Here \(s_M^2\) is the sample variance of \(M\), and \(s_{D0}^2\) is the mean
square of \(D\) about zero. This makes stable and lag-zero summaries invariant
to independently swapping complete member series within dyads. At positive
lags, pool own-member edges across members and cross-partner edges across both
directions.

## Lag support

Build edges from exact integer time differences. With `lags = NULL`, consider
only exact observed gaps from 1 through 5; do not fill unobserved intermediate
lags. Display a lag only when every applicable curve has adequate numbers of
contributing dyads and edges. The two numeric thresholds are **unresolved** and
must be selected during Gaussian validation rather than guessed.

Return and display both counts for every curve point. Explicitly requested
unsupported lags must error with curve-specific counts. Never silently discard
a replicate whose displayed statistic is undefined.

## Validation gates

Before implementation, validate:

- stable and lag-zero invariance after independently swapping complete member
  series within exchangeable dyads;
- distinct role-specific own-lag curves in an asymmetric persistence scenario,
  such as AR = .80 versus .20, where pooling could look adequate;
- pooled own- and cross-lag invariance without roles;
- exact-gap automatic selection that skips unsupported intermediate lags;
- curve-specific dyad and edge counts and explicit unsupported-lag errors;
- role-factor reordering that swaps labels rather than values; and
- covariance-compensation scenarios, diagnostic sensitivity, model-based SEs,
  and interval coverage.

Validate Gaussian `glmmTMB` first. Extend only to backend/family paths with a
validated centre and informative response-scale statistic.
[Gistelinck and Loeys (2019)](https://doi.org/10.1080/10705511.2018.1527223)
and [Pillinger et al. (2024)](https://doi.org/10.1093/jrsssa/qnad115) motivate
the stable/dynamic targets; neither paper prescribes this predictive-simulation
procedure.
