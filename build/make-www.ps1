# PowerShell port of build/make-www.js — same job, no Node.js required.
# Copies the static app into www/ for Capacitor (APK), stamps a build version into index.html
# (root AND www) so the "Periksa pembaruan" button and the ?v= cache-busts stay fresh.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File build\make-www.ps1
$ErrorActionPreference = "Stop"

$ROOT = Split-Path -Parent $PSScriptRoot
$WWW  = Join-Path $ROOT "www"

$FILES = @(
  "index.html",
  "fonts.css",
  "style.css",
  "surah-meta.js",
  "ayah-page.js",
  "quran-api.js",
  "page-layout.js",
  "qcf-font.js",
  "audio.js",
  "app.js"
)

# e.g. 2026-11-15T16:00 — URL-safe, matches the JS script's ISO format (invariant culture so the
# time separator stays a colon ":" rather than the locale's ".", which some cultures would use)
$VERSION = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH\:mm", [Globalization.CultureInfo]::InvariantCulture)

$indexPath = Join-Path $ROOT "index.html"
$html = [IO.File]::ReadAllText($indexPath)

if ($html -notmatch '<meta\s+name="app-version"\s+content="[^"]*"') {
  Write-Error "index.html is missing the app-version meta - the update check would silently break"
  exit 1
}

# stamp the version
$html = [regex]::Replace($html, '(<meta\s+name="app-version"\s+content=")[^"]*(")', "`${1}$VERSION`${2}")

# re-stamp every local asset's ?v= query
foreach ($f in $FILES) {
  if ($f -eq "index.html") { continue }
  $esc = [regex]::Escape($f)
  $html = [regex]::Replace($html, "=`"$esc\?v=[^`"]*`"", "=`"$f`"")
  $html = [regex]::Replace($html, "=`"$esc`"", "=`"$f`?v=$VERSION`"")
}

# rebuild www/
if (Test-Path $WWW) { Remove-Item $WWW -Recurse -Force }
New-Item -ItemType Directory -Force -Path $WWW | Out-Null

foreach ($f in $FILES) {
  $dest = Join-Path $WWW $f
  if ($f -eq "index.html") {
    [IO.File]::WriteAllText($dest, $html)
  } else {
    Copy-Item (Join-Path $ROOT $f) $dest -Force
  }
}

# page-specific QCF glyph fonts — copied wholesale so the APK renders the Mushaf view offline.
# Absent before build/download-qcf-fonts.ps1 ran; qcf-font.js then falls back to the CDN.
$qcfSrc = Join-Path $ROOT "fonts\qcf"
if (Test-Path $qcfSrc) {
  $qcfDest = Join-Path $WWW "fonts\qcf"
  New-Item -ItemType Directory -Force -Path $qcfDest | Out-Null
  $woff2 = Get-ChildItem $qcfSrc -Filter *.woff2 -File
  foreach ($w in $woff2) { Copy-Item $w.FullName (Join-Path $qcfDest $w.Name) -Force }
  Write-Output ("  + fonts/qcf: " + $woff2.Count + " woff2 files")
} else {
  Write-Warning "  ! fonts/qcf missing - run build/download-qcf-fonts.ps1 for offline page fonts (CDN fallback will be used)"
}

# the live site IS this file (GitHub Pages serves the repo root)
[IO.File]::WriteAllText($indexPath, $html)
Write-Output ("www/ ready: " + $FILES.Count + " files, version " + $VERSION)
