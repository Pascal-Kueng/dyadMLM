(function () {
  "use strict";

  function initialize(root) {
    if (!root || root.dataset.wdgInitialized === "true") return;
    root.dataset.wdgInitialized = "true";

    var limit = Number(root.dataset.limit);
    var scale = 130 / limit;
    var slopes = {
      actor: Number(root.dataset.actor),
      partner: Number(root.dataset.partner),
      mean: Number(root.dataset.mean),
      within: Number(root.dataset.within)
    };
    var colors = {
      actor: "var(--interdep-actor-effect)",
      partner: "var(--interdep-partner-effect)",
      mean: "var(--interdep-dyad-mean-effect)",
      within: "var(--interdep-member-deviation-effect)"
    };
    var inputs = {};
    var outputs = {};
    ["actor", "partner", "mean", "within"].forEach(function (name) {
      inputs[name] = root.querySelector('[data-wdg-input="' + name + '"]');
      outputs[name] = root.querySelector('[data-wdg-output="' + name + '"]');
    });

    var plot = root.querySelector("[data-wdg-plot]");
    var point = root.querySelector("[data-wdg-point]");
    var halo = root.querySelector("[data-wdg-halo]");
    var description = root.querySelector("[data-wdg-description]");
    var equationAPIM = root.querySelector('[data-wdg-equation="apim"]');
    var equationDIM = root.querySelector('[data-wdg-equation="dim"]');
    var slopeSummary = root.querySelector("[data-wdg-slopes]");

    function clamp(value) {
      return Math.min(limit, Math.max(-limit, Number(value)));
    }

    function clean(value) {
      return Math.abs(value) < 1e-10 ? 0 : value;
    }

    function format(value, digits) {
      return clean(value).toFixed(digits).replace("-", "−");
    }

    function coefficient(value, following) {
      value = clean(value);
      var magnitude = Math.abs(value).toFixed(2);
      if (!following) return value < 0 ? "−" + magnitude : magnitude;
      return value < 0 ? " − " + magnitude : " + " + magnitude;
    }

    function equation(
      firstSlope, firstValue, secondSlope, secondValue, result,
      firstRole, secondRole
    ) {
      var operator = secondSlope < 0 ? "−" : "+";
      return '<span class="wdg-eq-number wdg-eq-' + firstRole + '">' +
        coefficient(firstSlope, false) + "</span> × " +
        '<span class="wdg-eq-number wdg-eq-' + firstRole + '">' +
        format(firstValue, 2) + "</span> " +
        '<span class="wdg-eq-operator">' + operator + "</span> " +
        '<span class="wdg-eq-number wdg-eq-' + secondRole + '">' +
        Math.abs(secondSlope).toFixed(2) + "</span> × " +
        '<span class="wdg-eq-number wdg-eq-' + secondRole + '">' +
        format(secondValue, 2) + "</span> = " +
        '<strong class="wdg-eq-result">' + format(result, 2) + "</strong>";
    }

    function xPixel(value) { return 160 + value * scale; }
    function yPixel(value) { return 160 - value * scale; }

    function render() {
      var actor = Number(inputs.actor.value);
      var partner = Number(inputs.partner.value);
      var mean = Number(inputs.mean.value);
      var within = Number(inputs.within.value);
      var apimResult = slopes.actor * actor + slopes.partner * partner;
      var dimResult = slopes.mean * mean + slopes.within * within;

      outputs.actor.value = format(actor, 2);
      outputs.partner.value = format(partner, 2);
      outputs.mean.value = format(mean, 2);
      outputs.within.value = format(within, 2);
      equationAPIM.innerHTML = equation(
        slopes.actor, actor, slopes.partner, partner, apimResult,
        "actor", "partner"
      );
      equationDIM.innerHTML = equation(
        slopes.mean, mean, slopes.within, within, dimResult,
        "mean", "within"
      );
      slopeSummary.innerHTML =
        "Fitted slopes: <i>b</i><sub>mean</sub> = <i>a</i> + <i>p</i> = " +
        coefficient(slopes.mean, false) +
        "; <i>b</i><sub>dev</sub> = <i>a</i> − <i>p</i> = " +
        coefficient(slopes.within, false);

      point.setAttribute("cx", xPixel(actor));
      point.setAttribute("cy", yPixel(partner));
      halo.setAttribute("cx", xPixel(actor));
      halo.setAttribute("cy", yPixel(partner));
      description.textContent =
        "Actor " + format(actor, 2) + ", partner " + format(partner, 2) +
        ", dyad mean " + format(mean, 2) + ", and member deviation " +
        format(within, 2) + ".";
    }

    function setFromAPIM(actor, partner) {
      actor = clamp(actor);
      partner = clamp(partner);
      inputs.actor.value = actor;
      inputs.partner.value = partner;
      inputs.mean.value = (actor + partner) / 2;
      inputs.within.value = (actor - partner) / 2;
      render();
    }

    function setFromDIM(mean, within, changed) {
      mean = Number(mean);
      within = Number(within);
      if (changed === "within") {
        var withinBound = limit - Math.abs(mean);
        within = Math.min(withinBound, Math.max(-withinBound, within));
      } else {
        var meanBound = limit - Math.abs(within);
        mean = Math.min(meanBound, Math.max(-meanBound, mean));
      }
      inputs.mean.value = mean;
      inputs.within.value = within;
      inputs.actor.value = mean + within;
      inputs.partner.value = mean - within;
      render();
    }

    inputs.actor.addEventListener("input", function () {
      setFromAPIM(inputs.actor.value, inputs.partner.value);
    });
    inputs.partner.addEventListener("input", function () {
      setFromAPIM(inputs.actor.value, inputs.partner.value);
    });
    inputs.mean.addEventListener("input", function () {
      setFromDIM(inputs.mean.value, inputs.within.value, "mean");
    });
    inputs.within.addEventListener("input", function () {
      setFromDIM(inputs.mean.value, inputs.within.value, "within");
    });
    root.querySelector("[data-wdg-reset]").addEventListener("click", function () {
      setFromAPIM(0, 0);
    });
    root.querySelector('[data-wdg-demo="mean"]').addEventListener("click", function () {
      setFromAPIM(1, 1);
    });
    root.querySelector('[data-wdg-demo="within"]').addEventListener("click", function () {
      setFromAPIM(1, -1);
    });

    function setFromPointer(event) {
      var bounds = plot.getBoundingClientRect();
      var svgX = (event.clientX - bounds.left) / bounds.width * 320;
      var svgY = (event.clientY - bounds.top) / bounds.height * 320;
      var actor = Math.round(((svgX - 160) / scale) * 20) / 20;
      var partner = Math.round(((160 - svgY) / scale) * 20) / 20;
      setFromAPIM(actor, partner);
    }

    var dragging = false;
    plot.addEventListener("pointerdown", function (event) {
      dragging = true;
      plot.setPointerCapture(event.pointerId);
      setFromPointer(event);
    });
    plot.addEventListener("pointermove", function (event) {
      if (dragging) setFromPointer(event);
    });
    plot.addEventListener("pointerup", function (event) {
      dragging = false;
      if (plot.hasPointerCapture(event.pointerId)) {
        plot.releasePointerCapture(event.pointerId);
      }
    });
    plot.addEventListener("pointercancel", function () { dragging = false; });

    function drawGrid() {
      var namespace = "http://www.w3.org/2000/svg";
      var lines = root.querySelector("[data-wdg-grid-lines]");
      var labels = root.querySelector("[data-wdg-axis-labels]");

      function addLine(x1, y1, x2, y2, color, opacity, dash) {
        var line = document.createElementNS(namespace, "line");
        line.setAttribute("x1", x1);
        line.setAttribute("y1", y1);
        line.setAttribute("x2", x2);
        line.setAttribute("y2", y2);
        line.setAttribute("stroke", color);
        line.setAttribute("stroke-opacity", opacity);
        line.setAttribute("stroke-width", dash ? "1" : "2");
        if (dash) line.setAttribute("stroke-dasharray", dash);
        lines.appendChild(line);
      }

      for (var tick = -limit; tick <= limit + 1e-10; tick += 1) {
        var isAxis = Math.abs(tick) < 1e-10;
        var isMajor = Math.abs(tick % 2) < 1e-10;
        var dash = isAxis ? null : "3 3";
        var opacity = isAxis ? "0.68" : (isMajor ? "0.44" : "0.24");
        addLine(xPixel(tick), 30, xPixel(tick), 290, colors.actor, opacity, dash);
        addLine(30, yPixel(tick), 290, yPixel(tick), colors.partner, opacity, dash);
        // Diagonal lines are colored by the coordinate direction they trace.
        addLine(xPixel(-limit), yPixel(2 * tick + limit), xPixel(limit),
          yPixel(2 * tick - limit), colors.within, opacity, dash);
        addLine(xPixel(-limit), yPixel(-limit - 2 * tick), xPixel(limit),
          yPixel(limit - 2 * tick), colors.mean, opacity, dash);
      }

      function addLabel(text, x, y, color, anchor) {
        var label = document.createElementNS(namespace, "text");
        label.setAttribute("x", x);
        label.setAttribute("y", y);
        label.setAttribute("fill", color);
        label.setAttribute("font-size", "11");
        label.setAttribute("font-weight", "700");
        label.setAttribute("text-anchor", anchor || "middle");
        label.textContent = text;
        labels.appendChild(label);
      }

      addLabel("actor", 286, 151, colors.actor, "end");
      addLabel("partner", 160, 22, colors.partner);
      addLabel("dyad mean", 247, 66, colors.mean);
      addLabel("deviation", 248, 261, colors.within);
    }

    drawGrid();
    setFromAPIM(0, 0);
  }

  function initializeAll() {
    document.querySelectorAll(".workshop-dim-grid").forEach(initialize);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initializeAll);
  } else {
    initializeAll();
  }
  document.addEventListener("slidechanged", initializeAll);
})();
