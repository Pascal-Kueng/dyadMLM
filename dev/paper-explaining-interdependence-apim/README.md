# Explaining interdependence in the APIM

Working materials for the covariance/path-tracing methods programme.

## Start here

- [Focused reading list](focused-reading-list.md): 15 core sources, presence in
  J-P's folder, method summaries, and ILD/temporal-level distinctions.
- [Current plan](plan.md): Paper 1's scope, argument, inference/validation,
  software, open decisions, and the two possible follow-up papers.
- [SEM and MLM practice](practice-sem-mlm.R): reproduce the supplied
  cross-sectional example and compare the two fitted partitions.
- [Figures and short outline](paper-outline.Rmd): the complete APIM, highlighted
  routes, waterfall, equal-total comparison, and the argument in section bullets.
- [Technical notes](paper-idea.Rmd): equations, worked examples, covariate and
  exchangeable identities, and the reusable figure code.
- [ILD talking points](ild-outline.md): Paper 2 outline with checked
  references, and the steps for [explore-ild.Rmd](explore-ild.Rmd).

The plan and notes were reconciled with the literature review on **1 September
2026**. Direct APIM decomposition, signed reporting, diagrams, and software have
precedents. Paper 1 now includes covariates/multiple predictors, exchangeability,
and evaluation of contribution-specific inference; the interval method and study
protocol remain to be selected. Keep planning decisions in `plan.md`, source
evidence in the review, and derivations in the technical notes.

## Literature and source evidence

The focused list is the main reading list. The full review and dated audits
retain related background and the search history.

- [Methods and citation map](method-scope-and-citation-map.md): methods versus
  applications, citation priorities, designs, covariates, and extension context.
- [Full annotated review](literature-review.md): all 51 references, verification
  limits, and the local-file inventory.
- [J-P's supplied materials](jp-materials-review-2026-09-13.md): bundle inventory,
  worked example, chapter/OSF assessment, and numerical checks.
- [October full-text audit](full-text-verification-2026-10-07.md): verified methods,
  excluded applications, and remaining access gaps.
- [September citation audit](citation-audit-2026-09-13.md) and
  [inventory](citation-audit-2026-09-13.json): citation-search coverage and decisions.

## Public material and local reference copies

| Location | Contents | Git treatment |
|:--|:--|:--|
| This folder | Our Markdown notes and R Markdown sources | Trackable |
| This folder's `.html` outputs | Locally rendered drafts | Ignored by `dev/.gitignore` |
| `../references/explaining-interdependence-apim/` | Third-party papers, chapters, slides, and supplements for this manuscript | Entire directory ignored |
| Other folders under `../references/` | Existing shared reference copies | Entire directory ignored; left in place |
| `references.bib` | Manuscript-specific bibliographic metadata | Trackable |
| `../../vignettes/references.bib` | Shared bibliographic metadata | Kept in its original location |
| `../../vignettes/diagram-helpers.Rinc` | Shared, project-authored diagram helpers | Kept in its original location |

Free-to-read does not automatically mean permission to redistribute. Some
licenses permit republication with conditions; our default is to publish only
citations, source links, and our own short summaries, not third-party full texts.
See the [PMC copyright guidance](https://pmc.ncbi.nlm.nih.gov/about/copyright/).
The repository's software license does not grant rights to the reference copies.

The `/references/` rule in `dev/.gitignore` covers every file type, not just PDFs.
Do not force-add these files. Git ignore is not access control, a backup, or a
way to remove already committed material from history. No files under
`dev/references/` were tracked when this folder was organized.

On another checkout, create the local directory as needed:

```sh
mkdir -p dev/references/explaining-interdependence-apim
```

Use descriptive filenames such as `2022-ferraris-et-al-social-support-well-being.pdf`
and record each source/version in the literature review. Missing local copies
are explicitly distinguished from sources already inspected online.

## Render from the repository root

```r
devtools::load_all(".")
rmarkdown::render("dev/paper-explaining-interdependence-apim/paper-idea.Rmd")
rmarkdown::render("dev/paper-explaining-interdependence-apim/paper-outline.Rmd")
```

Both outputs are self-contained HTML. The short outline reuses the technical
notes' figure chunks; edit the figures there rather than maintaining duplicates.
Display equations retain `$$` delimiters and render as MathML.
The technical notes use both bibliography files; keep manuscript-only additions
in this folder. Source access does not imply permission to redistribute full text.
