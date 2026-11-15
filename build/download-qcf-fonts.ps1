# Downloads the QCF V2 page fonts (matching the API's code_v2 glyphs) used by the Mushaf view.
# Source: quran.com's own font CDN (same files the reference frontend serves), page 1..604.
# Saved as QCF_P001.woff2 .. QCF_P604.woff2 so the app can load fonts/qcf/QCF_P<n>.woff2 locally
# (offline-safe, matches the loader in qcf-font.js). Re-run to refresh; existing files are skipped
# unless -Force is passed.
param([switch]$Force)

$base = "https://quran.com/fonts/quran/hafs/v2/woff2/p"
$dest = Join-Path $PSScriptRoot "..\fonts\qcf"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$ok = 0; $skip = 0; $fail = @()
for ($n = 1; $n -le 604; $n++) {
  $name = "QCF_P" + $n.ToString("000") + ".woff2"
  $out  = Join-Path $dest $name
  if ((Test-Path $out) -and -not $Force) { $skip++; continue }
  $url = "$base$n.woff2"
  $done = $false
  for ($try = 1; $try -le 3 -and -not $done; $try++) {
    try {
      Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -ErrorAction Stop
      $done = $true; $ok++
    } catch {
      if ($try -eq 3) { $fail += "$n ($($_.Exception.Message))" }
    }
  }
  if (($n % 25) -eq 0) { Write-Output ("... $n / 604  (ok=$ok skip=$skip fail=" + $fail.Count + ")") }
}

$files = Get-ChildItem $dest -Filter *.woff2
$total = ($files | Measure-Object -Property Length -Sum).Sum
Write-Output "DONE ok=$ok skip=$skip fail=$($fail.Count) files=$($files.Count) totalMB=$([math]::Round($total/1MB,1))"
if ($fail.Count) { Write-Output ("FAILED: " + ($fail -join ", ")) }
