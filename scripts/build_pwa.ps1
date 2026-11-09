param([string]$BaseHref = '/', [string]$GoogleClientId = '')
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    node scripts/load-build-env.mjs --client-id $GoogleClientId
    if ($LASTEXITCODE -ne 0) { throw 'Environment configuration failed' }
    flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --base-href $BaseHref --dart-define-from-file=.dart_tool/build-config.json
    if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed' }
    node scripts/prepare_pwa.mjs
    if ($LASTEXITCODE -ne 0) { throw 'PWA preparation failed' }
} finally {
    Pop-Location
}
