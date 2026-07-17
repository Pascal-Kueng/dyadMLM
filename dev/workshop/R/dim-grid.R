dim_reparameterization_grid <- function(
    model, id = "workshop-dim-grid", predictor_label = "Predictor", limit = 4) {
  if (!inherits(model, "glmmTMB")) {
    stop("`model` must be a fitted glmmTMB exchangeable APIM.", call. = FALSE)
  }
  if (!is.numeric(limit) || length(limit) != 1L || !is.finite(limit) || limit <= 0) {
    stop("`limit` must be one positive number.", call. = FALSE)
  }

  fitted <- .extract_apim_diagram_values(model, type = "exchangeable")
  actor <- unname(fitted$estimates[["actor"]])
  partner <- unname(fitted$estimates[["partner"]])
  slopes <- c(
    actor = actor,
    partner = partner,
    mean = actor + partner,
    within = actor - partner
  )
  if (any(!is.finite(slopes))) {
    stop("The fitted APIM slopes must be finite.", call. = FALSE)
  }

  number <- function(x) {
    trimws(formatC(x, digits = 17, format = "g", decimal.mark = "."))
  }
  escape <- htmltools::htmlEscape
  id <- gsub("[^A-Za-z0-9_-]", "-", id)

  htmltools::HTML(sprintf(
'<div class="workshop-dim-grid" id="%s"
     data-limit="%s" data-actor="%s" data-partner="%s"
     data-mean="%s" data-within="%s">
  <div class="wdg-controls">
    <div class="wdg-toolbar">
      <strong>%s coordinates</strong>
      <button type="button" data-wdg-reset>Reset</button>
    </div>

    <div class="wdg-control-group">
      <div class="wdg-group-title wdg-apim-title">APIM coordinates</div>
      <label class="wdg-control wdg-actor">
        <span><span>Actor, <i>x</i><sub>actor</sub></span><output data-wdg-output="actor">0.0</output></span>
        <input data-wdg-input="actor" type="range" min="-%s" max="%s" step="0.1" value="0">
      </label>
      <label class="wdg-control wdg-partner">
        <span><span>Partner, <i>x</i><sub>partner</sub></span><output data-wdg-output="partner">0.0</output></span>
        <input data-wdg-input="partner" type="range" min="-%s" max="%s" step="0.1" value="0">
      </label>
    </div>

    <div class="wdg-control-group">
      <div class="wdg-group-title wdg-dim-title">DIM coordinates</div>
      <label class="wdg-control wdg-mean">
        <span><span>Dyad mean, <i>x</i><sub>mean</sub></span><output data-wdg-output="mean">0.00</output></span>
        <input data-wdg-input="mean" type="range" min="-%s" max="%s" step="0.05" value="0">
      </label>
      <label class="wdg-control wdg-within">
        <span><span>Within-dyad member deviation, <i>x</i><sub>dev</sub></span><output data-wdg-output="within">0.00</output></span>
        <input data-wdg-input="within" type="range" min="-%s" max="%s" step="0.05" value="0">
      </label>
    </div>

    <div class="wdg-relations">
      <span><i>x</i><sub>mean</sub> = (<i>x</i><sub>actor</sub> + <i>x</i><sub>partner</sub>) / 2</span>
      <span><i>x</i><sub>dev</sub> = (<i>x</i><sub>actor</sub> − <i>x</i><sub>partner</sub>) / 2</span>
    </div>
  </div>

  <div class="wdg-visual">
    <div class="wdg-equations">
      <div><b>APIM</b> <span data-wdg-equation="apim"></span></div>
      <div><b>DIM</b> <span data-wdg-equation="dim"></span></div>
      <div class="wdg-slope-summary" data-wdg-slopes></div>
    </div>

    <div class="wdg-stage">
      <svg class="wdg-plot" data-wdg-plot viewBox="0 0 320 320" role="img"
           aria-labelledby="%s-title %s-description">
        <title id="%s-title">APIM and DIM coordinate grid</title>
        <desc id="%s-description" data-wdg-description>The selected point is the grand-mean reference.</desc>
        <defs><clipPath id="%s-clip"><rect x="30" y="30" width="260" height="260" rx="4"></rect></clipPath></defs>
        <rect x="30" y="30" width="260" height="260" rx="4" fill="none" stroke="currentColor" stroke-opacity="0.32"></rect>
        <g data-wdg-grid-lines clip-path="url(#%s-clip)"></g>
        <g data-wdg-axis-labels></g>
        <circle class="wdg-halo" data-wdg-halo cx="160" cy="160" r="13"></circle>
        <circle class="wdg-point" data-wdg-point cx="160" cy="160" r="6"></circle>
      </svg>

      <div class="wdg-demos">
        <button type="button" data-wdg-demo="mean"><b>Shared dyad level</b><span>Both members +1</span></button>
        <div><i>b</i><sub>mean</sub> = <i>a</i> + <i>p</i></div>
        <button type="button" data-wdg-demo="within"><b>Within-dyad member deviation</b><span>Actor +1, partner −1</span></button>
        <div><i>b</i><sub>dev</sub> = <i>a</i> − <i>p</i></div>
        <p>Drag the dot or move either set of sliders. Both equations give the same fitted change in MVPA.</p>
      </div>
    </div>
  </div>
</div>',
    id, number(limit), number(slopes[["actor"]]), number(slopes[["partner"]]),
    number(slopes[["mean"]]), number(slopes[["within"]]), escape(predictor_label),
    number(limit), number(limit), number(limit), number(limit),
    number(limit), number(limit), number(limit), number(limit),
    id, id, id, id, id, id
  ))
}
