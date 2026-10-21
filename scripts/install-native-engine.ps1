# OTOMASI Native Engine Installer (preview, fail closed until releases are approved).
# This is NOT the older hosted-connector helper. Requires a verified source-only engine
# release that implements per-device pairing; never copies production WIN-OTO state.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('plc','easyeda','fusion')]
  [string]$Service,
  [switch]$DryRun,
  [switch]$CheckOnly,
  [string]$ManifestUrl = 'https://raw.githubusercontent.com/rofiqcp/otomasi-mcp-installer-hub/feat/portable-native-engines/runtime/engines.json'
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
function Tell($text) { Write-Host "[OTOMASI $Service] $text" -ForegroundColor Cyan }
function Halt($text) { throw "[OTOMASI $Service] BLOCKED: $text" }
if($env:OS -ne 'Windows_NT'){ Halt 'Requires Windows native PowerShell and an interactive user session.' }
if($env:OTOMASI_INSTALL_DRY_RUN -eq '1'){$DryRun=$true}
$base=Join-Path $env:LOCALAPPDATA 'OTOMASI\MCP'
$runtime=Join-Path $base 'runtime'
$engines=Join-Path $base 'engines'
Tell ('Install root: '+$base)
Tell 'No vendor software, database, OAuth key, cloud token, or PLC firmware is bundled by this installer.'
if($DryRun) {
  Tell 'DRY RUN. No packages installed, services touched, or user account changed.'
  Tell 'Verified release + device broker are required before new-PC deployment.'
  return
}
if(-not $ManifestUrl.StartsWith('https://raw.githubusercontent.com/rofiqcp/otomasi-mcp-installer-hub/')){
  Halt 'Manifest source is not the authorized OTOMASI GitHub repository.'
}
try {
  $m=Invoke-RestMethod -UseBasicParsing -Uri $ManifestUrl -TimeoutSec 20
}catch{
  Halt ('Release manifest unavailable: '+$_.Exception.Message)
}
if($m.schema_version -ne 1){Halt 'Unknown manifest schema. Refusing to execute unrecognized release.'}
$e=$m.engines.$Service
if(-not $e){Halt 'No engine configuration for this service.'}
if($e.release_available -ne $true){
  Halt ($e.blocker+' No native source release yet; hosted MCP login is supported without installing a local engine.')
}
if($e.broker_compatible -ne $true){
  Halt 'Release has no verified multi-device broker; would route tools to the wrong computer.'
}
if(-not $e.version -or $e.version -notmatch '^\d+\.\d+\.\d+$'){Halt 'Invalid engine SemVer.'}
if(-not $e.sha256 -or $e.sha256 -notmatch '^[a-fA-F0-9]{64}$'){Halt 'Release must have a pinned SHA256.'}
if(-not $e.source_url -or -not $e.source_url.StartsWith('https://github.com/rofiqcp/otomasi-mcp-installer-hub/releases/download/')){
  Halt 'Release archive must come from the authorized GitHub Releases project.'
}
Tell ('Approved release: '+$Service+'@'+$e.version)
if($CheckOnly){
  Tell 'Manifest is release-ready; dependencies and vendor apps still require verification.'
  return
}
function Has-Node {
  $command=Get-Command node.exe -ErrorAction SilentlyContinue
  if(-not $command){return $false}
  $ver=(& $command.Source --version 2>$null)
  return ($LASTEXITCODE -eq 0 -and $ver -match '^v(\d+)\.' -and [int]$Matches[1] -ge 22)
}
function Has-Python {
  $command=Get-Command py.exe -ErrorAction SilentlyContinue
  if(-not $command){$command=Get-Command python.exe -ErrorAction SilentlyContinue}
  if(-not $command){return $false}
  $pyArgs=@('-c','import sys;assert sys.version_info >= (3,10)')
  if($command.Name -ieq 'py.exe'){$pyArgs=@('-3')+$pyArgs}
  & $command.Source @pyArgs 2>$null
  return $LASTEXITCODE -eq 0
}
function Require-Winget($package) {
  $w=Get-Command winget.exe -ErrorAction SilentlyContinue
  if(-not $w){Halt 'Windows App Installer (winget) is required for dependency installation.'}
  Tell ('Installing official package '+$package)
  & $w.Source install --id $package --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
  if($LASTEXITCODE -ne 0){Halt ('winget failed for '+$package+'. Open a new PowerShell after installing manually.')}
  $env:PATH=[Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')
}
if(-not (Has-Node)){Require-Winget 'OpenJS.NodeJS.LTS';if(-not (Has-Node)){Halt 'Node 22+ is not visible after install; reopen PowerShell.'}}
if($Service -in @('plc','fusion') -and -not (Has-Python)){
  Require-Winget 'Python.Python.3.12'
  if(-not (Has-Python)){Halt 'Python >=3.10 is not visible after install; reopen PowerShell.'}
}
foreach($p in @($base,$runtime,$engines)){New-Item -ItemType Directory -Force -Path $p|Out-Null}
$target=Join-Path (Join-Path $engines $Service) $e.version
if(Test-Path $target){Halt 'This release folder already exists. Use the update/verify workflow; never overwrite silently.'}
$createdTarget=$false
$staging=Join-Path $env:TEMP ('otomasi-mcp-'+$Service+'-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $staging|Out-Null
try {
  $zip=Join-Path $staging 'engine.zip'
  Tell 'Downloading the pinned native engine source release...'
  Invoke-WebRequest -UseBasicParsing -Uri $e.source_url -OutFile $zip -TimeoutSec 120
  $digest=(Get-FileHash $zip -Algorithm SHA256).Hash
  if($digest -ne $e.sha256){Halt 'Release SHA256 mismatch; archive quarantined and execution aborted.'}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $extract=Join-Path $staging 'payload'
  New-Item -ItemType Directory -Force -Path $extract|Out-Null
  $archive=[IO.Compression.ZipFile]::OpenRead($zip)
  try {
    $canonical=[IO.Path]::GetFullPath($extract+[IO.Path]::DirectorySeparatorChar)
    foreach($entry in $archive.Entries){
      $full=[IO.Path]::GetFullPath((Join-Path $extract $entry.FullName))
      if(-not $full.StartsWith($canonical,[System.StringComparison]::OrdinalIgnoreCase)){
        Halt 'Archive contains an unsafe traversal entry.'
      }
    }
  }finally{$archive.Dispose()}
  [IO.Compression.ZipFile]::ExtractToDirectory($zip,$extract)
  $entry=Join-Path $extract 'engine\install.ps1'
  $verify=Join-Path $extract 'engine\verify.ps1'
  if(-not (Test-Path $entry) -or -not (Test-Path $verify)){Halt 'Release must include install.ps1 and verify.ps1.'}
  New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent)|Out-Null
  Move-Item -LiteralPath $extract -Destination $target
  $createdTarget=$true
  Tell 'Running source-only engine setup in the interactive user account...'
  & (Join-Path $target 'engine\install.ps1') -Root $base -Service $Service
  if(-not $?){Halt 'Engine setup returned failure.'}
  & (Join-Path $target 'engine\verify.ps1') -Root $base -Service $Service
  if(-not $?){Halt 'Engine verification did not pass.'}
  Tell ('VERIFIED '+$Service+' engine '+$e.version)
}catch{
  if($createdTarget -and (Test-Path $target)){
    Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
  }
  Tell 'Native engine deployment failed. The previous engine installation is left untouched.'
  throw
}finally{
  Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
}
