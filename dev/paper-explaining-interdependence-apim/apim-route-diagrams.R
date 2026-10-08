# Path diagrams for the APIM covariance decomposition, optionally with one
# covariate C. Dev only, not part of the package. Builds on the vignette
# diagram helpers and the route diagrams in paper-idea.Rmd.
#
# Model (partner subscripts name the outcome member, as in Kenny):
#   Y1 = a1 X1 + p1 X2 + c1 C + e1
#   Y2 = a2 X2 + p2 X1 + c2 C + e2
#
# Every route joins one path into Y1 with one path into Y2, through the
# variance or covariance of the variables those two paths start from. A
# variance is drawn as a loop on top of the variable's box.
#
#   source("apim-route-diagrams.R")
#   draw_apim_routes("actor_driven")
#   draw_apim_routes(apim_buckets$mixed, covariate = TRUE)
#   draw_apim_route_grid(list("Mixed" = apim_buckets$mixed), covariate = TRUE)
#
# With results: `labels` names the variables, `roles` the two members,
# `values` and `p_values` give estimates for the paths, variances and
# covariances (named a1, a2, p1, p2, c1, c2, var_x1, var_x2, var_c, cov_x1_x2,
# cov_x1_c, cov_x2_c, psi), and `contributions` gives the size of each route
# (named as in apim_routes).
# Percentages are relative to the sum of all routes.

local({
  helper_file <- c(
    "../../vignettes/diagram-helpers.Rinc",
    "../vignettes/diagram-helpers.Rinc",
    "vignettes/diagram-helpers.Rinc"
  )
  helper_file <- helper_file[file.exists(helper_file)][1]
  if (is.na(helper_file)) stop("Cannot find vignettes/diagram-helpers.Rinc.")
  sys.source(helper_file, envir = globalenv())
})

diagram_colours <- c(
  actor = unname(.interdep_effect_colors("actor")),
  partner = unname(.interdep_effect_colors("partner")),
  covariate = "#2F7D4F",
  covariance = "#334155",
  residual = "#546E7A",
  ink = "#263238",
  faint = "#C6CFD8",
  surface = "#F8FAFC"
)

# Each route: the path into Y1, the path into Y2, and what links their
# sources (a covariance or a variance). S1 and S2 stand for the two members'
# subscripts.
apim_routes <- list(
  actor_driven = list(
    paths = c("a1", "a2"), link = "cov_x1_x2",
    formula = quote(a[S1] * a[S2] %.% Cov(X[S1], X[S2]))
  ),
  partner_driven = list(
    paths = c("p1", "p2"), link = "cov_x1_x2",
    formula = quote(p[S1] * p[S2] %.% Cov(X[S1], X[S2]))
  ),
  x1_driven = list(
    paths = c("a1", "p2"), link = "var_x1",
    formula = quote(a[S1] * p[S2] %.% Var(X[S1]))
  ),
  x2_driven = list(
    paths = c("p1", "a2"), link = "var_x2",
    formula = quote(p[S1] * a[S2] %.% Var(X[S2]))
  ),
  covariate_driven = list(
    paths = c("c1", "c2"), link = "var_c",
    formula = quote(c[S1] * c[S2] %.% Var(italic(C)))
  ),
  x1_actor_with_c = list(
    paths = c("a1", "c2"), link = "cov_x1_c",
    formula = quote(a[S1] * c[S2] %.% Cov(X[S1], italic(C)))
  ),
  c_with_x1_partner = list(
    paths = c("c1", "p2"), link = "cov_x1_c",
    formula = quote(c[S1] * p[S2] %.% Cov(X[S1], italic(C)))
  ),
  c_with_x2_actor = list(
    paths = c("c1", "a2"), link = "cov_x2_c",
    formula = quote(c[S1] * a[S2] %.% Cov(X[S2], italic(C)))
  ),
  x2_partner_with_c = list(
    paths = c("p1", "c2"), link = "cov_x2_c",
    formula = quote(p[S1] * c[S2] %.% Cov(X[S2], italic(C)))
  ),
  residual = list(
    paths = c("e1", "e2"), link = "psi",
    formula = quote(Cov(epsilon[S1], epsilon[S2]))
  )
)

# Routes grouped into the buckets of the decomposition.
apim_buckets <- list(
  predictor = c("actor_driven", "partner_driven", "x1_driven", "x2_driven"),
  covariate = "covariate_driven",
  mixed = c(
    "x1_actor_with_c", "c_with_x1_partner",
    "c_with_x2_actor", "x2_partner_with_c"
  ),
  residual = "residual"
)

# Positions of nodes, paths and arcs, without and with the covariate. Paths
# give the heights where they start and end, and how far along the path their
# label sits. Arcs (covariances and variances) give their start, end,
# curvature and label position.
apim_layout <- function(covariate) {
  if (!covariate) {
    return(list(
      nodes = list(
        X1 = c(0.25, 0.70), X2 = c(0.25, 0.30),
        Y1 = c(0.71, 0.70), Y2 = c(0.71, 0.30),
        e1 = c(0.88, 0.70), e2 = c(0.88, 0.30)
      ),
      box = c(width = 0.19, height = 0.19),
      paths = list(
        a1 = list(from = "X1", to = "Y1", y = c(0.70, 0.70), label = 0.50),
        a2 = list(from = "X2", to = "Y2", y = c(0.30, 0.30), label = 0.50),
        p2 = list(from = "X1", to = "Y2", y = c(0.67, 0.34), label = 0.30),
        p1 = list(from = "X2", to = "Y1", y = c(0.33, 0.66), label = 0.30)
      ),
      arcs = list(
        cov_x1_x2 = list(from = c(0.155, 0.67), to = c(0.155, 0.33),
                         curvature = 0.32, label = c(0.085, 0.50)),
        var_x1 = list(from = c(0.225, 0.795), to = c(0.275, 0.795),
                      curvature = -1, label = c(0.25, 0.88)),
        var_x2 = list(from = c(0.225, 0.395), to = c(0.275, 0.395),
                      curvature = -1, label = c(0.25, 0.48))
      )
    ))
  }
  list(
    nodes = list(
      X1 = c(0.29, 0.74), C = c(0.29, 0.46), X2 = c(0.29, 0.18),
      Y1 = c(0.72, 0.68), Y2 = c(0.72, 0.24),
      e1 = c(0.895, 0.68), e2 = c(0.895, 0.24)
    ),
    box = c(width = 0.16, height = 0.13),
    paths = list(
      a1 = list(from = "X1", to = "Y1", y = c(0.76, 0.73), label = 0.50),
      c1 = list(from = "C", to = "Y1", y = c(0.49, 0.68), label = 0.70),
      p1 = list(from = "X2", to = "Y1", y = c(0.20, 0.63), label = 0.20),
      p2 = list(from = "X1", to = "Y2", y = c(0.72, 0.29), label = 0.20),
      c2 = list(from = "C", to = "Y2", y = c(0.43, 0.24), label = 0.70),
      a2 = list(from = "X2", to = "Y2", y = c(0.16, 0.19), label = 0.50)
    ),
    arcs = list(
      cov_x1_c = list(from = c(0.21, 0.70), to = c(0.21, 0.50),
                      curvature = 1.1, label = c(0.15, 0.60)),
      cov_x2_c = list(from = c(0.21, 0.42), to = c(0.21, 0.22),
                      curvature = 1.1, label = c(0.15, 0.32)),
      cov_x1_x2 = list(from = c(0.21, 0.78), to = c(0.21, 0.14),
                       curvature = 0.75, label = c(0.06, 0.46)),
      var_x1 = list(from = c(0.265, 0.805), to = c(0.315, 0.805),
                    curvature = -1, label = c(0.29, 0.885)),
      var_c = list(from = c(0.265, 0.525), to = c(0.315, 0.525),
                   curvature = -1, label = c(0.29, 0.605)),
      var_x2 = list(from = c(0.265, 0.245), to = c(0.315, 0.245),
                    curvature = -1, label = c(0.29, 0.325))
    )
  )
}

# Fill the member subscripts S1 and S2 into an expression.
with_roles <- function(expression, roles) {
  do.call(substitute, list(expression, list(S1 = roles[[1]], S2 = roles[[2]])))
}

# Draw one APIM and highlight the given routes. `routes` can be route names,
# a bucket, or "all". Draws into the current viewport.
draw_apim_routes <- function(routes = "all", covariate = FALSE, title = NULL,
                             labels = NULL, roles = c("1", "2"),
                             values = NULL, p_values = NULL,
                             contributions = NULL,
                             formula = NULL, text_scale = 1, newpage = TRUE) {
  available <- names(apim_routes)
  if (!covariate) {
    available <- setdiff(available, unlist(apim_buckets[c("covariate", "mixed")]))
  }
  if (identical(routes, "all")) routes <- available
  stopifnot(all(routes %in% available))

  # Subscripts: numbers stay numbers, role names are set upright. With role
  # names, residuals, variances and covariances are drawn without subscripts.
  word_roles <- !all(grepl("^[0-9]+$", roles))
  roles <- lapply(roles, \(role) {
    if (grepl("^[0-9]+$", role)) as.numeric(role) else call("plain", as.name(role))
  })

  layout <- apim_layout(covariate)
  half_width <- layout$box[["width"]] / 2
  native <- function(value) grid::unit(value, "native")
  colour_if <- function(on, colour) if (on) colour else diagram_colours[["faint"]]
  arrow_head <- grid::arrow(
    angle = 28, length = grid::unit(0.12 * text_scale, "inches"), type = "closed"
  )
  double_arrow <- grid::arrow(
    angle = 26, length = grid::unit(0.09 * text_scale, "inches"),
    ends = "both", type = "closed"
  )

  # Everything the highlighted routes use, and the variables their paths
  # start from.
  active <- unique(unlist(lapply(apim_routes[routes], \(r) c(r$paths, r$link))))
  is_active <- function(element) element %in% active
  source_nodes <- vapply(
    intersect(active, names(layout$paths)), \(p) layout$paths[[p]]$from, ""
  )

  # Label of a path or arc: its symbol, plus its estimate when highlighted.
  element_label <- function(name, symbol) {
    symbol <- with_roles(symbol, roles)
    if (is.null(values) || !is_active(name) || !name %in% names(values)) {
      return(symbol)
    }
    p_value <- if (name %in% names(p_values)) p_values[[name]] else NULL
    .diagram_estimate_label(symbol, values[[name]], p_value)
  }
  draw_label <- function(label, x, y, on, colour) {
    .draw_residual_annotation(
      label, x, y, fontsize = 13 * text_scale, colour = colour_if(on, colour)
    )
  }

  if (newpage) grid::grid.newpage()
  grid::pushViewport(grid::viewport(xscale = c(0, 1), yscale = c(0, 1)))
  on.exit(grid::popViewport(), add = TRUE)

  # Faint elements first, highlighted ones on top. All labels come after
  # all lines, so no line crosses a label.
  by_activity <- function(names) names[order(is_active(names))]

  # Paths into the outcomes, from the right edge of the source box to the
  # left edge of the outcome box. A path's name is its type (a, p or c) and
  # the member it points to: a1 is a[S1].
  path_colours <- c(a = "actor", p = "partner", c = "covariate")
  path_geometry <- function(name) {
    path <- layout$paths[[name]]
    x <- c(
      layout$nodes[[path$from]][1] + half_width,
      layout$nodes[[path$to]][1] - half_width - .diagram_arrow_clearance
    )
    list(
      x = x, y = path$y,
      label_x = x[1] + path$label * (x[2] - x[1]),
      label_y = path$y[1] + path$label * (path$y[2] - path$y[1]),
      colour = diagram_colours[[path_colours[[substr(name, 1, 1)]]]]
    )
  }
  for (name in by_activity(names(layout$paths))) {
    path <- path_geometry(name)
    colour <- colour_if(is_active(name), path$colour)
    grid::grid.segments(
      native(path$x[1]), native(path$y[1]), native(path$x[2]), native(path$y[2]),
      arrow = arrow_head,
      gp = grid::gpar(
        col = colour, fill = colour,
        lwd = (if (is_active(name)) 2.4 else 1.2) * text_scale
      )
    )
  }

  # Covariances and variances of predictors, as curved double-headed arrows.
  arc_symbols <- list(
    cov_x1_x2 = quote(sigma[X[S1] * X[S2]]),
    cov_x1_c = quote(sigma[X[S1] * italic(C)]),
    cov_x2_c = quote(sigma[X[S2] * italic(C)]),
    var_x1 = quote(sigma[X[S1]]^2),
    var_x2 = quote(sigma[X[S2]]^2),
    var_c = quote(sigma[italic(C)]^2)
  )
  if (word_roles) {
    arc_symbols[] <- list(quote(sigma))
    arc_symbols[startsWith(names(arc_symbols), "var")] <- list(quote(sigma^2))
  }
  for (name in by_activity(names(layout$arcs))) {
    arc <- layout$arcs[[name]]
    on <- is_active(name)
    colour <- colour_if(on, diagram_colours[["covariance"]])
    grid::grid.curve(
      native(arc$from[1]), native(arc$from[2]), native(arc$to[1]), native(arc$to[2]),
      curvature = arc$curvature, angle = 90, ncp = 12, square = FALSE,
      arrow = double_arrow,
      gp = grid::gpar(col = colour, fill = colour,
                      lwd = (if (on) 2 else 1.2) * text_scale)
    )
  }

  # Labels of paths and arcs, on top of all lines.
  for (name in by_activity(names(layout$paths))) {
    path <- path_geometry(name)
    symbol <- str2lang(paste0(substr(name, 1, 1), "[S", substr(name, 2, 2), "]"))
    draw_label(element_label(name, symbol), path$label_x, path$label_y,
               is_active(name), path$colour)
  }
  for (name in by_activity(names(layout$arcs))) {
    arc <- layout$arcs[[name]]
    draw_label(element_label(name, arc_symbols[[name]]), arc$label[1],
               arc$label[2], is_active(name), diagram_colours[["covariance"]])
  }

  # Residuals point into the outcomes; psi is their covariance.
  on <- is_active("psi")
  residual_colour <- colour_if(on, diagram_colours[["residual"]])
  for (member in c("1", "2")) {
    e <- layout$nodes[[paste0("e", member)]]
    y <- layout$nodes[[paste0("Y", member)]]
    grid::grid.segments(
      native(e[1] - 0.035), native(e[2]),
      native(y[1] + half_width + .diagram_arrow_clearance), native(y[2]),
      arrow = arrow_head,
      gp = grid::gpar(col = residual_colour, fill = residual_colour,
                      lwd = (if (on) 2.4 else 1.2) * text_scale)
    )
  }
  e1 <- layout$nodes$e1
  e2 <- layout$nodes$e2
  grid::grid.curve(
    native(e1[1] + 0.03), native(e1[2] - 0.04),
    native(e2[1] + 0.03), native(e2[2] + 0.04),
    curvature = -0.28, angle = 90, ncp = 12, square = FALSE, arrow = double_arrow,
    gp = grid::gpar(col = residual_colour, fill = residual_colour,
                    lwd = (if (on) 2 else 1.2) * text_scale)
  )
  psi_symbol <- if (word_roles) quote(italic("\u03c8")) else quote(italic("\u03c8")[S1 * S2])
  draw_label(element_label("psi", psi_symbol),
             e1[1], (e1[2] + e2[2]) / 2, on, diagram_colours[["residual"]])

  # Nodes. Predictors used by a highlighted route are dark.
  member_label <- function(variable, symbol, member) {
    if (is.null(labels[[variable]])) {
      return(with_roles(substitute(SYMBOL[S], list(SYMBOL = symbol, S = member)), roles))
    }
    with_roles(substitute(plain(NAME)[S], list(NAME = labels[[variable]], S = member)), roles)
  }
  node_labels <- list(
    X1 = member_label("predictor", quote(X), quote(S1)),
    X2 = member_label("predictor", quote(X), quote(S2)),
    C = if (is.null(labels$covariate)) quote(italic(C)) else labels$covariate,
    Y1 = member_label("outcome", quote(Y), quote(S1)),
    Y2 = member_label("outcome", quote(Y), quote(S2)),
    e1 = if (word_roles) quote(epsilon) else with_roles(quote(epsilon[S1]), roles),
    e2 = if (word_roles) quote(epsilon) else with_roles(quote(epsilon[S2]), roles)
  )
  word_labels <- !is.null(labels)
  for (name in names(layout$nodes)) {
    position <- layout$nodes[[name]]
    residual_node <- name %in% c("e1", "e2")
    on <- if (residual_node) is_active("psi") else name %in% c("Y1", "Y2", source_nodes)
    node_colour <- colour_if(on, diagram_colours[["ink"]])
    gp <- grid::gpar(
      fill = if (residual_node) "white" else diagram_colours[["surface"]],
      col = node_colour, lwd = 1.8 * text_scale
    )
    if (residual_node) {
      grid::grid.circle(native(position[1]), native(position[2]),
                        r = grid::unit(0.05, "snpc"), gp = gp)
    } else {
      grid::grid.roundrect(
        native(position[1]), native(position[2]),
        width = native(layout$box[["width"]]),
        height = native(layout$box[["height"]]),
        r = grid::unit(0.04, "snpc"), gp = gp
      )
    }
    font_size <- if (residual_node) 15 else if (word_labels) 14 else 19
    grid::grid.text(
      .diagram_math_label(as.expression(node_labels[[name]])),
      native(position[1]), native(position[2]),
      gp = grid::gpar(col = node_colour, fontsize = font_size * text_scale)
    )
  }

  # Title, and below the diagram the formula with the contribution.
  if (!is.null(title)) {
    grid::grid.text(
      title, native(0.03), native(0.955), just = "left",
      gp = grid::gpar(col = diagram_colours[["ink"]],
                      fontsize = 15 * text_scale, fontface = "bold")
    )
  }
  if (is.null(formula) && length(routes) == 1L) formula <- apim_routes[[routes]]$formula
  if (!is.null(formula)) formula <- with_roles(formula, roles)
  if (!is.null(contributions)) {
    total <- sum(contributions[available])
    value <- sum(contributions[routes])
    # Adding 0 turns a rounded -0 into 0.
    amount <- sprintf("%.3f (%.1f%%)", round(value, 3) + 0,
                      round(100 * value / total, 1) + 0)
    formula <- if (is.null(formula)) {
      substitute(plain(Contribution) == plain(AMOUNT), list(AMOUNT = amount))
    } else {
      substitute(FORMULA == plain(AMOUNT), list(FORMULA = formula, AMOUNT = amount))
    }
  }
  if (!is.null(formula)) {
    grid::grid.text(
      .diagram_math_label(as.expression(formula)), native(0.50), native(0.045),
      gp = grid::gpar(col = diagram_colours[["ink"]], fontsize = 13 * text_scale)
    )
  }
  invisible(NULL)
}

# Several panels in a grid. `panels` is a named list: title = routes. Other
# arguments, such as `labels` or `values`, are passed to draw_apim_routes().
draw_apim_route_grid <- function(panels, ncol = 2, formulas = list(),
                                 text_scale = 0.9, ...) {
  arguments <- list(...)
  nrow <- ceiling(length(panels) / ncol)
  key_height <- if (is.null(arguments$p_values)) 0 else 0.4
  grid::grid.newpage()
  grid::pushViewport(grid::viewport(layout = grid::grid.layout(
    nrow + 1, ncol,
    heights = grid::unit(c(rep(1, nrow), key_height), c(rep("null", nrow), "inches"))
  )))
  for (index in seq_along(panels)) {
    grid::pushViewport(grid::viewport(
      layout.pos.row = (index - 1L) %/% ncol + 1L,
      layout.pos.col = (index - 1L) %% ncol + 1L
    ))
    do.call(draw_apim_routes, c(
      list(panels[[index]], title = names(panels)[index],
           formula = formulas[[names(panels)[index]]],
           text_scale = text_scale, newpage = FALSE),
      arguments
    ), quote = TRUE)
    grid::popViewport()
  }
  # One key for the significance stars, below all panels.
  if (key_height > 0) {
    grid::pushViewport(grid::viewport(layout.pos.row = nrow + 1, layout.pos.col = seq_len(ncol)))
    grid::pushViewport(grid::viewport(xscale = c(0, 1), yscale = c(0, 1)))
    .draw_diagram_significance_key(TRUE, y = 0.5, fontsize = 11)
    grid::popViewport(2)
  }
  grid::popViewport()
  invisible(NULL)
}
