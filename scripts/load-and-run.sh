#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
version="${1:-1.0.0}"

case "$(uname -m)" in
  x86_64|amd64) architecture="amd64" ;;
  aarch64|arm64) architecture="arm64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

archive="$project_dir/dist/cas-edge-proxy-${version}-linux-${architecture}.tar.gz"
if [[ ! -f "$archive" ]]; then
  echo "Image archive not found: $archive" >&2
  exit 1
fi

docker load --input "$archive"
docker compose --file "$project_dir/compose.yaml" up --detach --no-build
docker compose --file "$project_dir/compose.yaml" ps
