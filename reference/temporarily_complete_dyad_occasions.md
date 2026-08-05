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

A `dyadMLM_data` object containing temporary missing-member rows and an
internal column recording the original row order.
