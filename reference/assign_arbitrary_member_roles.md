# Assign arbitrary member roles within dyads

Creates a member-level lookup with one arbitrary role per observed
member. The assignment is stable across longitudinal rows because it is
made once per `group` x `member`.

## Usage

``` r
assign_arbitrary_member_roles(data, group_name, member_name, seed = NULL)
```

## Arguments

- data:

  A data frame.

- group_name:

  Name of the dyad/group column.

- member_name:

  Name of the member/person column.

- seed:

  Optional seed for random arbitrary partner-role assignment. If `NULL`,
  the current R session's RNG state is used.

## Value

A data frame with `group_name`, `member_name`, and `.i_arbitrary_role`.
