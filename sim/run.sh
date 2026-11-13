#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TB="${1:-tb_ray_gen}"
cd "$ROOT"
vsim -c -do "set TB ${TB}; do sim/run.do"
