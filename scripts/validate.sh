#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"

docker run --rm \
  --volume "$project_dir/config/config.json:/config/config.json:ro" \
  cas-edge-proxy:1.0.0 \
  --config /config/config.json --validate
