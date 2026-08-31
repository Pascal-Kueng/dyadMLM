# Explaining interdependence in the APIM

Working materials for the covariance/path-tracing methods paper.

## Start here

- [Literature review](literature-review.md): annotated references, direct
  applications, writing examples, verification gaps, and the local-file inventory.
- [Figures and short outline](paper-outline.Rmd): the complete APIM, highlighted
  routes, waterfall, equal-total comparison, and the argument in section bullets.
- [Detailed paper idea](paper-idea.Rmd): equations, worked examples, figure code,
  proposed design, and the longer manuscript blueprint.

The literature review was assembled on **31 August 2026**. The drafts predate
parts of that search: direct APIM decomposition, correlation-unit reporting,
diagrams, and software already have precedents. Read the review before reusing
the drafts' novelty language. Inference, simulations, extensions, target journal,
and collaboration workflow remain decisions to agree, not a finalized protocol.

## Public material and local reference copies

| Location | Contents | Git treatment |
|:--|:--|:--|
| This folder | Our Markdown notes and R Markdown sources | Trackable |
| This folder's `.html` outputs | Locally rendered drafts | Ignored by `dev/.gitignore` |
| `../references/explaining-interdependence-apim/` | Third-party papers, chapters, slides, and supplements for this manuscript | Entire directory ignored |
| Other folders under `../references/` | Existing shared reference copies | Entire directory ignored; left in place |
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

Both outputs are self-contained HTML. The short outline reuses the detailed
draft's figure chunks; edit the figures there rather than maintaining duplicates.
Display equations retain `$$` delimiters and render as MathML.

## Before developing the manuscript further

- Resolve the contribution against the direct precedents in the literature review.
- Obtain the Dwyer calculation supplement and the full 2024 handbook chapter.
- Agree on descriptive reporting versus contribution-specific inference, and
  select validation studies to match those claims.
- Update the draft and its citations together; the literature review currently
  contains sources not yet incorporated into the shared BibTeX file.
