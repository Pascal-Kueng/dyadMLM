# References for model estimation

These papers define dyadic models, covariance parameterizations,
random-effects structures, or the modeling software used to estimate them.
Some also support the package's simulation checks; those uses are cross-linked
from the [simulation-check index](../simulation_checks/README.md) rather than
represented by duplicate PDF copies.

## Local PDFs

| Local file | Reference and source | Main use in `dyadMLM` |
|---|---|---|
| `2005-woody-sadler-interchangeable-dyads.pdf` | Woody, E., & Sadler, P. (2005). Structural equation models for interchangeable dyads: Being the same makes a difference. *Psychological Methods, 10*(2), 139–158. [doi:10.1037/1082-989X.10.2.139](https://doi.org/10.1037/1082-989X.10.2.139). | Primary source for the interchangeable-dyad moment construction. Page 142 defines the centered mean and uncentered difference sample matrices; the Appendix on p. 158 derives their variance/covariance back-transformation. |
| `2017-buerkner-brms.pdf` | Bürkner, P.-C. (2017). `brms`: An R package for Bayesian multilevel models using Stan. *Journal of Statistical Software, 80*(1), 1–28. [doi:10.18637/jss.v080.i01](https://doi.org/10.18637/jss.v080.i01); [publisher PDF](https://www.jstatsoft.org/index.php/jss/article/download/v080i01/1143). | Primary software reference for the Bayesian modeling backend. Current `brms` documentation remains authoritative for exact prediction-call semantics. |
| `2018-iida-seidman-shrout-dyadic-score-model.pdf` | Iida, M., Seidman, G., & Shrout, P. E. (2018; first published online 2017). Models of interdependent individuals versus dyadic processes in relationship research. *Journal of Social and Personal Relationships, 35*(1), 59–88. [doi:10.1177/0265407517725407](https://doi.org/10.1177/0265407517725407). | Primary source for choosing among the APIM, common-fate model, and Dyadic Score Model, including the DSM level-and-difference equations used by the package. |
| `2023-kenny-ackerman-sum-difference-random-effects.pdf` | Kenny, D. A., & Ackerman, R. A. (2023, July 4). *Estimation of Random Effects in Over-Time Dyadic Data Using Multilevel Modeling: The Sum and Difference Method*. [OSF PDF](https://osf.io/download/fju72/). | Direct technical treatment of sum/difference random-effect blocks and covariance back-transformations in longitudinal dyadic MLMs. |
| `2025-del-rosario-west-random-effects-dyadic-mlm.pdf` | del Rosario, K. S., & West, T. V. (2025). A practical guide to specifying random effects in longitudinal dyadic multilevel modeling. *Advances in Methods and Practices in Psychological Science, 8*(3), 1–36. [doi:10.1177/25152459251351286](https://doi.org/10.1177/25152459251351286). | Peer-reviewed guide to implementing dyadic random effects, including the sum/difference workaround adapted from Kenny and Ackerman. It does not originate the response-summary diagnostic. |

## Relevant work without a stored PDF

- Olsen, J. A., & Kenny, D. A. (2006). Structural equation modeling with
  interchangeable dyads. *Psychological Methods, 11*(2), 127–141.
  [doi:10.1037/1082-989X.11.2.127](https://doi.org/10.1037/1082-989X.11.2.127).
  Useful background on exchangeability constraints and label invariance, but
  secondary to Woody and Sadler (2005) for the present implementation.

Sources and access were checked on 2026-08-22.
