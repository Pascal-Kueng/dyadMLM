# Temporarily complete observed dyad occasions

Adds the missing member row when only one member is present at an
observed dyad occasion. Structural identifiers and a resolved stable
role are kept; all measured variables are missing on the added row. The
added rows are used only while model-ready columns are constructed.

## Usage

``` r
temporarily_complete_dyad_occasions(data)
```

## Arguments

- data:

  A validated `dyadMLM_data` object.

## Value

A list containing the temporarily completed data and the original
observed row keys.
