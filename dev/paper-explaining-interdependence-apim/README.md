# Explaining interdependence in the APIM

Paper 1 is cross-sectional ([paper-1-outline.md](paper-1-outline.md)),
Paper 2 uses intensive longitudinal data ([ild-outline.md](ild-outline.md)),
and Paper 3 on generalized outcomes follows only if justified (see
[paper-1-outline.md](paper-1-outline.md)).

## Files

- [paper-1-outline.md](paper-1-outline.md): Paper 1 outline.
- [ild-outline.md](ild-outline.md): Paper 2 talking points and references.
- [literature.md](literature.md): master literature list.
- [explore-sem-mlm.Rmd](explore-sem-mlm.Rmd): cross-sectional example in
  lavaan and glmmTMB, with bootstrap CIs. It uses
  [explore-sem-mlm.css](explore-sem-mlm.css) and
  [apim-route-diagrams.R](apim-route-diagrams.R), which loads
  `../../vignettes/diagram-helpers.Rinc`.
- [explore-sem-mlm-details.Rmd](explore-sem-mlm-details.Rmd): checks of the
  bootstrap and other CIs. It reuses the main notebook's cache.
- [explore-ild.Rmd](explore-ild.Rmd): diary example with the T&T data.

## Data

- `explore-sem-mlm.Rmd` reads the FLASHE example from
  `../references/explaining-interdependence-apim/jp-materials-2026-09-13/J-P&Niall-FLASHE-example/flashe-lavaan.csv`.
  This is a git-ignored local copy from J-P's `Relevant Papers and
  Resources.zip` (UMass workshop, July 2025; 1,486 complete dyads, one row
  per dyad). `flashesmall.csv` in the same folder has the same numbers with
  Mplus names.
- `explore-ild.Rmd` loads
  `../../../00DashboardsTimeAndTies/Merged_Dataset_long.rda` from the
  dashboards repository next to `dyadMLM`.

## Rendering

Render from the repository root after `devtools::load_all(".")`, or install
dyadMLM. Knit `explore-sem-mlm.Rmd` first, since it caches the bootstrap, and
then `explore-sem-mlm-details.Rmd`. `dev/.gitignore` ignores the HTML output
and the `*_cache/` and `*_files/` folders.

## Local reference copies

Third-party papers, chapters, slides and supplements stay in
`dev/references/explaining-interdependence-apim/`, which `dev/.gitignore`
ignores. Never force-add these files, and do not treat git-ignore as a backup.
Free to read does not mean free to redistribute, so we publish only
citations, links and our own summaries (see the
[PMC copyright guidance](https://pmc.ncbi.nlm.nih.gov/about/copyright/)).
On a new checkout, create the folder with
`mkdir -p dev/references/explaining-interdependence-apim` and use descriptive
file names, such as `2022-ferraris-et-al-social-support-well-being.pdf`.
