#!/usr/bin/env bash
# Run the scheduled jobs that are due, once (what the midnight trigger does in production).
source "$(dirname "$0")/_lib.sh"
[[ -f app/__main__.py ]] || {
  echo "app/__main__.py is missing: see CHANGELOG.md (Unreleased, manual steps)" >&2
  exit 1
}
run python -m app run-due-jobs
