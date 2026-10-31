# Developer notes

Design notes, drafts and helpers for developing dyadMLM. This folder is not part of the package build. Planned work is tracked in the [GitHub milestones](https://github.com/Pascal-Kueng/dyadMLM/milestones).

## Design notes

- [centering.md](centering.md): temporal predictor decomposition and how APIM, DIM and DSM columns are built.
- [dsm.md](dsm.md): the directional Dyadic Score Model, its derivation and its link to the APIM and DIM.
- [backtransform.md](backtransform.md): maths behind `recover_exchangeable_covariance()`. The code, help and tests decide the exact behaviour.
- [ild-nonindependence.md](ild-nonindependence.md): sources of non-independence in diary data, and the wording the vignettes use for them.
- [dyadic-ild-current-options.md](dyadic-ild-current-options.md): which AR(1) and VAR structures glmmTMB and brms can fit for dyadic diary data.
- [dyadic-ild-ar1-var-tutorial.md](dyadic-ild-ar1-var-tutorial.md): applied guide to choosing AR(1) or VAR structures in glmmTMB.
- [stan.md](stan.md): staged plan for a custom Stan dyadic residual VAR(1) model. Provisional: revise it against the methods literature before implementing. The papers it cites under `References/` are kept locally only.
- [paper-explaining-interdependence-apim/](paper-explaining-interdependence-apim/): outlines, literature and worked examples for the papers on the APIM covariance decomposition. Provisional.
- [paper-idea-exchangeable-location-scale-dim-apim.md](paper-idea-exchangeable-location-scale-dim-apim.md): paper idea for an exchangeable DIM in which the dyad average relates to how much partners differ. Provisional.

## Model checks

- [diagnostic_checks/README.md](diagnostic_checks/README.md): how the partner-dependence checks work, and how to run their validation scripts and reports.
- [diagnostic_checks/ild-partner-dependence-plan.md](diagnostic_checks/ild-partner-dependence-plan.md): design of the checks for repeated occasions. The planned lag statistics are in [#132](https://github.com/Pascal-Kueng/dyadMLM/issues/132).
- [diagnostic_checks/simulation-studies/README.md](diagnostic_checks/simulation-studies/README.md): simulation studies behind the check articles, and how to rerun them.

## Drafts and helpers

- [vignettes/](vignettes/): unpublished drafts for the generalized APIM, multiple dyad compositions (`mixed-apim.Rmd`) and its recovery study (`articles/mixed-apim-recovery.Rmd`), the Common Fate Model, and an exchangeable location-scale DIM.
- [workshop/](workshop/): workshop slides, exercises and data. The pkgdown workflow renders the slides for the website's workshop page and packs them with the exercises and data into a ZIP, so changes here go live.
- [debug-data-preparation.R](debug-data-preparation.R): scratch helpers to step through the internals of `prepare_dyad_data()`.

## Decisions

- dyadMLM prepares data, checks models and helps interpret results. Fitting stays with glmmTMB, brms and other engines.
- `prepare_dyad_data()` does not keep incomplete dyads or dyads with unknown roles as rows only for inspection. Revisit this only for a concrete user need.
- Releases: copy the checklist of [#58](https://github.com/Pascal-Kueng/dyadMLM/issues/58), which also covers the Zenodo concept DOI.
