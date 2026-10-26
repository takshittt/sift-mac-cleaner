#!/bin/zsh
# UI smoke test: launches the built Sift.app on fake data and walks
# scan → select → confirm → clean → report (see Sources/Sift/SmokeTest.swift).
# Never touches real files. Exits non-zero on failure.
set -euo pipefail
root=${0:A:h:h}
"$root/scripts/build-app.sh" debug >/dev/null
"$root/build/Sift.app/Contents/MacOS/Sift" --smoke-test
