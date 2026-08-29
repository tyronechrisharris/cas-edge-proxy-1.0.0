param(
    [string]$Version = "1.0.0",
    [ValidateSet("amd64", "arm64")]
    [string]$Architecture = "amd64"
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot
$DistDir = Join-Path $ProjectDir "dist"
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

$Archive = Join-Path $DistDir "cas-edge-proxy-$Version-linux-$Architecture.tar"
docker buildx build `
    --platform "linux/$Architecture" `
    --build-arg "VERSION=$Version" `
    --tag "cas-edge-proxy:$Version" `
    --output "type=docker,dest=$Archive" `
    $ProjectDir
if ($LASTEXITCODE -ne 0) {
    throw "Docker build failed."
}

$Hash = Get-FileHash -Algorithm SHA256 $Archive
"$($Hash.Hash.ToLower())  $($Hash.Path | Split-Path -Leaf)" | Set-Content (Join-Path $DistDir "SHA256SUMS.txt")
Write-Host "Offline image bundle created: $Archive"
