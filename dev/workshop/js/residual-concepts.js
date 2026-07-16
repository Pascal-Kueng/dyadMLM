(function () {
  "use strict";

  const SVG_NS = "http://www.w3.org/2000/svg";
  const ROOT_STYLES = window.getComputedStyle(document.documentElement);
  const cssColor = (name, fallback) => (
    ROOT_STYLES.getPropertyValue(name).trim() || fallback
  );
  const FEMALE = cssColor("--interdep-residual-female", "#004d40");
  const MALE = cssColor("--interdep-residual-male", "#00a6b2");
  const MALE_TEXT = cssColor("--interdep-residual-male-text", "#007486");
  const INK = "#263238";
  const MUTED = "#64748b";
  const GRID = "#dbe3ec";
  const SURFACE = "#f6f8fb";

  function center(values) {
    const mean = values.reduce((sum, value) => sum + value, 0) / values.length;
    return values.map((value) => value - mean);
  }

  function dot(left, right) {
    return left.reduce((sum, value, index) => sum + value * right[index], 0);
  }

  function standardize(values) {
    const centered = center(values);
    const sampleSd = Math.sqrt(dot(centered, centered) / (centered.length - 1));
    return centered.map((value) => value / sampleSd);
  }

  // Fixed patterns avoid random redraws. Gram-Schmidt makes the patterns
  // orthogonal, so each slider sets its displayed parameter exactly.
  const femalePattern = standardize([
    0.10, -1.20, 1.40, -0.30, 0.90,
    -0.80, 0.60, -1.00, 0.40, -0.10
  ]);
  const maleSeed = center([
    -1.553354, -0.944651, 0.609074, -0.212816, -0.293429,
    1.274519, -1.175546, 0.338836, 1.257615, 0.699752
  ]);
  const projection = dot(maleSeed, femalePattern) / dot(femalePattern, femalePattern);
  const malePattern = standardize(
    maleSeed.map((value, index) => value - projection * femalePattern[index])
  );

  function svgElement(name, attributes, textContent) {
    const element = document.createElementNS(SVG_NS, name);
    Object.entries(attributes || {}).forEach(([key, value]) => {
      element.setAttribute(key, String(value));
    });
    if (textContent !== undefined) element.textContent = textContent;
    return element;
  }

  function append(parent, name, attributes, textContent) {
    const child = svgElement(name, attributes, textContent);
    parent.appendChild(child);
    return child;
  }

  function addMultilineText(parent, lines, x, y, attributes) {
    const text = append(parent, "text", { x, y, ...attributes });
    lines.forEach((line, index) => {
      append(text, "tspan", { x, dy: index === 0 ? 0 : "1.05em" }, line);
    });
    return text;
  }

  function scale(value, domainMin, domainMax, rangeMin, rangeMax) {
    const proportion = (value - domainMin) / (domainMax - domainMin);
    return rangeMin + proportion * (rangeMax - rangeMin);
  }

  function drawText(parent, x, y, text, className, extra) {
    return append(parent, "text", { x, y, class: className, ...(extra || {}) }, text);
  }

  const textMeasureContext = document.createElement("canvas").getContext("2d");

  function textWidth(text, size, weight) {
    textMeasureContext.font = `${weight} ${size}px Source Sans Pro, Helvetica Neue, Arial, sans-serif`;
    return textMeasureContext.measureText(text).width;
  }

  function drawCenteredText(parent, centerX, y, text, className, size, weight, extra) {
    return drawText(
      parent,
      centerX - textWidth(text, size, weight) / 2,
      y,
      text,
      className,
      extra
    );
  }

  function init(widget) {
    if (widget.dataset.initialized === "true") return;
    widget.dataset.initialized = "true";

    const svg = widget.querySelector("svg");
    const femaleVarianceInput = widget.querySelector('[data-parameter="female-variance"]');
    const maleVarianceInput = widget.querySelector('[data-parameter="male-variance"]');
    const correlationInput = widget.querySelector('[data-parameter="correlation"]');
    const resetButton = widget.querySelector("[data-action='reset']");
    const femaleOutput = widget.querySelector('[data-output="female-variance"]');
    const maleOutput = widget.querySelector('[data-output="male-variance"]');
    const correlationOutput = widget.querySelector('[data-output="correlation"]');

    const defaults = {
      femaleVariance: 0.5,
      maleVariance: 3.0,
      correlation: 0.7
    };

    function render() {
      const femaleVariance = Number(femaleVarianceInput.value);
      const maleVariance = Number(maleVarianceInput.value);
      const correlation = Number(correlationInput.value);
      const femaleSd = Math.sqrt(femaleVariance);
      const maleSd = Math.sqrt(maleVariance);
      const orthogonalWeight = Math.sqrt(1 - correlation * correlation);

      // One linked set of dyads. Scaling either pattern changes its sample
      // variance without changing the selected sample correlation.
      const femaleResiduals = femalePattern.map((value) => femaleSd * value);
      const maleResiduals = femalePattern.map(
        (value, index) => (
          maleSd * (correlation * value + orthogonalWeight * malePattern[index])
        )
      );

      femaleOutput.value = femaleVariance.toFixed(1);
      femaleOutput.textContent = femaleVariance.toFixed(1);
      maleOutput.value = maleVariance.toFixed(1);
      maleOutput.textContent = maleVariance.toFixed(1);
      correlationOutput.value = correlation.toFixed(1);
      correlationOutput.textContent = correlation.toFixed(1);

      while (svg.firstChild) svg.removeChild(svg.firstChild);
      svg.setAttribute(
        "aria-label",
        `Linked dyads with residual variances ${femaleVariance.toFixed(1)} and ` +
          `${maleVariance.toFixed(1)}, and residual correlation ` +
          `${correlation.toFixed(1)}.`
      );

      const left = append(svg, "g", { class: "residual-left-panel" });
      drawText(left, 48, 24, "Residual = observed − predicted", "rc-title");
      drawText(left, 48, 46, "Line length shows each person’s residual", "rc-subtitle");

      const panelLeft = 48;
      const panelRight = 704;
      const pointLeft = 88;
      const pointRight = 678;
      // Leave extra room above the prediction so large positive residuals do not
      // collide with the facet title. This places the baseline just below centre.
      const outcomeMin = 5;
      const outcomeMax = 16;
      const predicted = 10;

      function drawResidualPanel(
        top, bottom, residuals, colour, label, labelColour = colour
      ) {
        append(left, "rect", {
          x: panelLeft,
          y: top,
          width: panelRight - panelLeft,
          height: bottom - top,
          rx: 8,
          class: "rc-panel-background"
        });

        const y = (outcome) => scale(outcome, outcomeMin, outcomeMax, bottom - 9, top + 9);
        const predictedY = y(predicted);
        append(left, "line", {
          x1: panelLeft + 8,
          x2: panelRight - 8,
          y1: predictedY,
          y2: predictedY,
          class: "rc-prediction-line"
        });
        drawText(left, panelLeft + 13, top + 20, label, "rc-facet-title", {
          fill: labelColour
        });
        drawText(left, panelRight - 13, predictedY - 6, "ŷ = 10", "rc-prediction-label", {
          "text-anchor": "end"
        });

        residuals.forEach((residual, index) => {
          const x = scale(index, 0, residuals.length - 1, pointLeft, pointRight);
          const observedY = y(predicted + residual);
          append(left, "line", {
            x1: x,
            x2: x,
            y1: predictedY,
            y2: observedY,
            stroke: colour,
            class: "rc-residual-line"
          });
          append(left, "circle", {
            cx: x,
            cy: observedY,
            r: 5,
            fill: colour,
            class: "rc-observed-point"
          });
        });
      }

      drawResidualPanel(
        62,
        220,
        femaleResiduals,
        FEMALE,
        `Female: residual variance σ²F = ${femaleVariance.toFixed(1)}`
      );
      drawResidualPanel(
        246,
        404,
        maleResiduals,
        MALE,
        `Male: residual variance σ²M = ${maleVariance.toFixed(1)}`,
        MALE_TEXT
      );

      femaleResiduals.forEach((unused, index) => {
        const x = scale(index, 0, femaleResiduals.length - 1, pointLeft, pointRight);
        drawCenteredText(left, x, 427, String(index + 1), "rc-tick-label", 13, 400);
      });
      drawCenteredText(
        left,
        (pointLeft + pointRight) / 2,
        466,
        "Illustrative dyad (arbitrary order)",
        "rc-axis-title",
        15,
        600
      );

      const right = append(svg, "g", { class: "residual-right-panel" });
      drawText(right, 760, 24, "Same dyads: do residuals move together?", "rc-title");
      const association = correlation > 0.05
        ? "positive association"
        : correlation < -0.05
          ? "negative association"
          : "no linear association";
      drawText(
        right,
        760,
        46,
        `Each point pairs two partners; ρFM = ${correlation.toFixed(1)} (${association})`,
        "rc-subtitle"
      );

      const plotLeft = 785;
      const plotRight = 1164;
      const plotTop = 62;
      const plotBottom = 404;
      const maleDomain = [-5, 5];
      const femaleDomain = [-5, 5];
      const x = (value) => scale(value, maleDomain[0], maleDomain[1], plotLeft, plotRight);
      const y = (value) => scale(value, femaleDomain[0], femaleDomain[1], plotBottom, plotTop);

      append(right, "rect", {
        x: plotLeft,
        y: plotTop,
        width: plotRight - plotLeft,
        height: plotBottom - plotTop,
        rx: 8,
        class: "rc-panel-background"
      });

      append(right, "line", {
        x1: plotLeft,
        x2: plotRight,
        y1: y(0),
        y2: y(0),
        class: "rc-zero-line"
      });
      append(right, "line", {
        x1: x(0),
        x2: x(0),
        y1: plotTop,
        y2: plotBottom,
        class: "rc-zero-line"
      });

      [-4, -2, 0, 2, 4].forEach((tick) => {
        drawCenteredText(
          right,
          x(tick),
          plotBottom + 21,
          String(tick),
          "rc-tick-label",
          13,
          400
        );
      });
      [-4, -2, 0, 2, 4].forEach((tick) => {
        drawText(right, plotLeft - 10, y(tick) + 4, String(tick), "rc-tick-label", {
          "text-anchor": "end"
        });
      });

      drawCenteredText(
        right,
        (plotLeft + plotRight) / 2,
        466,
        "Male partner residual",
        "rc-axis-title",
        15,
        600
      );
      const femaleAxisLabel = "Female partner residual";
      drawText(
        right,
        736 - textWidth(femaleAxisLabel, 15, 600) / 2,
        (plotTop + plotBottom) / 2,
        femaleAxisLabel,
        "rc-axis-title",
        { transform: `rotate(-90 736 ${(plotTop + plotBottom) / 2})` }
      );

      // Reserve the lower-right corner for the scale-free correlation guide.
      // Negative-correlation text is kept immediately to its left.
      const guideCenterX = plotRight - 56;
      const guideCenterY = plotBottom - 49;
      const guideRadius = 36;
      const guideLeft = guideCenterX - 48;

      if (correlation > 0.05) {
        addMultilineText(right, ["both above", "prediction"], plotRight - 10, plotTop + 19, {
          class: "rc-quadrant-label",
          "text-anchor": "end"
        });
        addMultilineText(right, ["both below", "prediction"], plotLeft + 10, plotBottom - 27, {
          class: "rc-quadrant-label",
          "text-anchor": "start"
        });
      } else if (correlation < -0.05) {
        addMultilineText(right, ["female above", "male below"], plotLeft + 10, plotTop + 19, {
          class: "rc-quadrant-label",
          "text-anchor": "start"
        });
        addMultilineText(right, ["male above", "female below"], guideLeft - 8, plotBottom - 27, {
          class: "rc-quadrant-label",
          "text-anchor": "end"
        });
      } else {
        drawCenteredText(
          right,
          (plotLeft + plotRight) / 2,
          plotTop + 19,
          "no systematic pairing",
          "rc-quadrant-label",
          13,
          600
        );
      }

      femaleResiduals.forEach((femaleResidual, index) => {
        const group = append(right, "g", { class: "rc-paired-point" });
        const pointX = x(maleResiduals[index]);
        const pointY = y(femaleResidual);
        append(group, "circle", {
          cx: pointX,
          cy: pointY,
          r: 10.5
        });
        const numberBox = append(group, "foreignObject", {
          x: pointX - 10.5,
          y: pointY - 10.5,
          width: 21,
          height: 21,
          class: "rc-point-number-box"
        });
        const number = document.createElement("div");
        number.textContent = String(index + 1);
        numberBox.appendChild(number);
      });

      // Draw the standardized guide last so it behaves like an inset above the
      // raw points. Its opaque background hides any observations beneath it.
      const guideBackground = append(right, "foreignObject", {
        x: guideLeft,
        y: guideCenterY - 42,
        width: 96,
        height: 84,
        class: "rc-correlation-guide-background"
      });
      const guideGlass = document.createElement("div");
      guideBackground.appendChild(guideGlass);
      drawCenteredText(
        right,
        guideCenterX,
        guideCenterY - 25,
        "scale-free ρ",
        "rc-correlation-guide-label",
        12,
        600
      );
      append(right, "line", {
        x1: guideCenterX - guideRadius,
        y1: guideCenterY,
        x2: guideCenterX + guideRadius,
        y2: guideCenterY,
        class: "rc-correlation-guide-axis"
      });
      append(right, "line", {
        x1: guideCenterX,
        y1: guideCenterY - 21,
        x2: guideCenterX,
        y2: guideCenterY + 21,
        class: "rc-correlation-guide-axis"
      });
      append(right, "line", {
        x1: guideCenterX - guideRadius,
        y1: guideCenterY + correlation * 21,
        x2: guideCenterX + guideRadius,
        y2: guideCenterY - correlation * 21,
        class: "rc-correlation-line"
      });
    }

    [femaleVarianceInput, maleVarianceInput, correlationInput].forEach((input) => {
      input.addEventListener("input", render);
      input.addEventListener("keydown", (event) => event.stopPropagation());
    });
    resetButton.addEventListener("click", () => {
      femaleVarianceInput.value = defaults.femaleVariance;
      maleVarianceInput.value = defaults.maleVariance;
      correlationInput.value = defaults.correlation;
      render();
      femaleVarianceInput.focus();
    });

    render();
  }

  document.querySelectorAll(".residual-concepts-widget").forEach(init);
})();
