param(
    [string]$Version = "1.0.0",
    [ValidateSet("amd64", "arm64")]
    [string]$Architecture = "amd64"
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot
$Archive = Join-Path $ProjectDir "dist/cas-edge-proxy-$Version-linux-$Architecture.tar"

if (-not (Test-Path $Archive)) {
    throw "Image archive not found: $Archive"
}

docker load --input $Archive
if ($LASTEXITCODE -ne 0) {
    throw "Docker could not load the image."
}
docker compose --file (Join-Path $ProjectDir "compose.yaml") up --detach --no-build
if ($LASTEXITCODE -ne 0) {
    throw "Docker Compose could not start the proxy."
}
docker compose --file (Join-Path $ProjectDir "compose.yaml") ps
