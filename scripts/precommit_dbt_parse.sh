#!/usr/bin/env bash
set -euo pipefail

if [ ! -d "dbt_packages" ]; then
  echo "dbt_packages not found, running dbt deps..."
  uv run dbt deps
fi

echo "Running dbt parse..."
uv run dbt parse --no-partial-parse
