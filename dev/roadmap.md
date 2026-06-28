
# Roadmap for 'interdep' R-Package
This package will provide functions for estimating dyadic models like APIMs, focusing
on cross-sectional and intensive longitudinal (ILD) data. 

## Version 0.1.0 - First CRAN-release candidate
- Validate dyadic data and return a tibble with all necessary columns and metadata
- Supports cross-sectional and ILD data for distinguishable and exchangeable dyads
  - Auto-detect roles and distinguishability
  - Constrain certain dyads to be exchangeable (e.g., male-female -> exch)
  - Pool certain dyads (e.g., male-male and female-female -> same-sex)
  - Vignette for data prep

## Version 0.2.0
- Write static code/syntax to estimate cross-sectional and ILD models using: 
  - glmmTMB code
  - (brms code + priors)
  - (dynamite) or other MLSEM/DSEM framework
  
## Version 0.3.0
- Estimation with the supported packages
- summaries
- diagnostics

