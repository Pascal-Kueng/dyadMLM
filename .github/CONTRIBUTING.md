# Contributing to dyadMLM

Thanks for considering a contribution. Bug reports, documentation and example
improvements, tests, code, and statistical or software review all help.

You do not need to write code. Testing a development feature or reviewing
whether its interpretation is clear can be just as useful.

## Getting Started

- Small documentation corrections and isolated test improvements can go
  directly into a pull request.
- Bugs and concrete improvements can start as an
  [Issue](https://github.com/Pascal-Kueng/dyadMLM/issues/new/choose).
- Open-ended method, API, or design ideas are welcome in
  [Ideas](https://github.com/Pascal-Kueng/dyadMLM/discussions/categories/ideas).

For substantial statistical or public API changes, a short discussion before
implementation usually makes the eventual contribution easier to review.

## Preparing a Pull Request

Focused pull requests are easiest to review. Briefly explain what changed and
why, and link an Issue or Discussion when there is one.

Edit source files rather than generated output:

- edit `README.Rmd`, then regenerate `README.md`;
- edit roxygen comments under `R/`, then regenerate files under `man/`; and
- edit vignette sources under `vignettes/` rather than rendered website files.

When relevant, add a focused test and a short `NEWS.md` entry. GitHub Actions
will run the automated package and website checks. If you tested the change
locally, feel free to mention how.

Please only use data you are permitted to share publicly. Never commit
identifiable or confidential research data.
