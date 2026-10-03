#!/usr/bin/env bash
# Unit tests for the pure core logic (runs on plain Node >= 22, no SDK needed).
set -euo pipefail
cd "$(dirname "$0")/.."
node tests/run.mjs
