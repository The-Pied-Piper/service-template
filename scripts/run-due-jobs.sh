#!/usr/bin/env bash
# Run the scheduled jobs that are due, once (what the midnight trigger does in production).
source "$(dirname "$0")/_lib.sh"
run python -m app run-due-jobs "$@"
