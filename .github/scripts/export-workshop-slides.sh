#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "${1:-.}" && pwd)"
workshop_output="${repository_root}/docs/workshop"
decktape_image="ghcr.io/astefanutti/decktape:3.16.1@sha256:66f5eff34a444628f5ab524da5390a454412fa879f3d15df96daf4c5c8da6b33"
temporary_root="$(mktemp -d /tmp/dyadmlm-decktape.XXXXXX)"
temporary_input="${temporary_root}/input"
temporary_output="${temporary_root}/output"

cleanup() {
  rm -rf -- "${temporary_root}"
}
trap cleanup EXIT

mkdir -p "${temporary_input}" "${temporary_output}" "${workshop_output}"

# Give the container only the publication-bound slide files.
cp "${repository_root}/dev/workshop/dyad-day.html" \
  "${temporary_input}/dyad-day.html"
cp "${repository_root}/dev/workshop/applied-tutorial.html" \
  "${temporary_input}/applied-tutorial.html"

# Fragments are intentionally disabled (DeckTape's default), yielding one PDF
# page per Reveal slide with ordinary fragments fully revealed.
docker run --rm \
  --volume "${temporary_input}:/slides:ro,Z" \
  --volume "${temporary_output}:/output:Z" \
  "${decktape_image}" reveal \
  --size 1050x700 \
  --pause 1500 \
  --load-pause 2000 \
  --chrome-arg=--allow-file-access-from-files \
  "file:///slides/dyad-day.html" \
  "/output/01_conceptual-foundations.pdf"

docker run --rm \
  --volume "${temporary_input}:/slides:ro,Z" \
  --volume "${temporary_output}:/output:Z" \
  "${decktape_image}" reveal \
  --size 1050x700 \
  --pause 1500 \
  --load-pause 2000 \
  --chrome-arg=--allow-file-access-from-files \
  "file:///slides/applied-tutorial.html" \
  "/output/02_applied-tutorial.pdf"

test -s "${temporary_output}/01_conceptual-foundations.pdf"
test -s "${temporary_output}/02_applied-tutorial.pdf"

install -m 0644 "${temporary_output}/01_conceptual-foundations.pdf" \
  "${workshop_output}/01_conceptual-foundations.pdf"
install -m 0644 "${temporary_output}/02_applied-tutorial.pdf" \
  "${workshop_output}/02_applied-tutorial.pdf"
