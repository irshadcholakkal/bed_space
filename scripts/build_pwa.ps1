param([string]$BaseHref = '/app/', [string]$GoogleClientId = '')
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    node scripts/load-build-env.mjs --client-id $GoogleClientId
    if ($LASTEXITCODE -ne 0) { throw 'Environment configuration failed' }
    flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --base-href $BaseHref --dart-define-from-file=.dart_tool/build-config.json
    if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed' }
    node scripts/prepare_pwa.mjs
    if ($LASTEXITCODE -ne 0) { throw 'PWA preparation failed' }
    if ($BaseHref -eq '/app/') {
        npm ci --prefix landing --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw 'Landing dependencies failed' }
        npm run build --prefix landing
        if ($LASTEXITCODE -ne 0) { throw 'Next.js landing build failed' }
        node scripts/assemble-site.mjs
        if ($LASTEXITCODE -ne 0) { throw 'Site assembly failed' }
    }
} finally {
    Pop-Location
}
