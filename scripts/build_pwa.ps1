param([string]$BaseHref = '/', [string]$GoogleClientId = '')
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    flutter build web --release --no-web-resources-cdn --base-href $BaseHref "--dart-define=GOOGLE_CLIENT_ID=$GoogleClientId"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed' }
    node scripts/prepare_pwa.mjs
    if ($LASTEXITCODE -ne 0) { throw 'PWA preparation failed' }
} finally {
    Pop-Location
}
