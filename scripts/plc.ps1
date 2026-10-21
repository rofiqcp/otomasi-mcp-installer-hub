# OTOMASI MCP service onboarding/bootstrap for existing WIN-OTO deployment.
# Separates the publicly hosted MCP connector from installing the original vendor backend.
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$Service='plc'
$Display='WECON PLC'
$McpUrl='https://mcp-plc.otomasi.app/mcp'
$Dashboard='https://mcp-plc.otomasi.app/'
$Health='https://mcp-plc.otomasi.app/health'
$LegacySource='C:\riset\mcp\PLC\server.cjs'
$LegacyPm2='otomasi-plc-mcp'
$RequiresNode=$true
$RequiresPython=$true
function Say([string]$s){Write-Host ('[OTOMASI '+$Display+'] '+$s) -ForegroundColor Cyan}
function Warn([string]$s){Write-Warning ('[OTOMASI '+$Display+'] '+$s)}
function FindNode {
  $n=Get-Command node.exe -ErrorAction SilentlyContinue
  if($n){
    $v=(& $n.Source --version 2>$null)
    if($LASTEXITCODE -eq 0 -and $v -match '^v([0-9]+)\.' -and [int]$Matches[1] -ge 22){return $n.Source}
  }
  return $null
}
function FindPython {
  $py=Get-Command py.exe -ErrorAction SilentlyContinue
  if($py){try{& $py.Source -3 -c 'import sys;assert sys.version_info >= (3,10)' 2>$null;if($LASTEXITCODE -eq 0){return $py.Source}}catch{}}
  $python=Get-Command python.exe -ErrorAction SilentlyContinue
  if($python){try{& $python.Source -c 'import sys;assert sys.version_info >= (3,10)' 2>$null;if($LASTEXITCODE -eq 0){return $python.Source}}catch{}}
  return $null
}
if($env:OTOMASI_INSTALL_DRY_RUN -eq '1'){Say 'DRY RUN: check Node/Python selectively, reuse native source if installed, register user startup only for verified PM2 process; publish no secrets.';return}
if($PSVersionTable.PSVersion.Major -lt 5){throw 'Windows PowerShell 5.1+ required'}
$root=Join-Path $env:LOCALAPPDATA 'OTOMASI\MCP'
$app=Join-Path $root ('agents\'+$Service)
$runtime=Join-Path $root 'runtime'
foreach($folder in @($root,$app,$runtime,(Join-Path $root 'logs'))){New-Item -ItemType Directory -Force -Path $folder | Out-Null}
$NativePresent=Test-Path -LiteralPath $LegacySource
$node=$null
if($RequiresNode -and $NativePresent){
  $node=FindNode
  if(-not $node){
    $winget=Get-Command winget.exe -ErrorAction SilentlyContinue
    if(-not $winget){Warn 'Install official Node.js 24 LTS from nodejs.org (or install Windows App Installer for winget), then retry.'}
    else {
      Say 'Installing supported Node.js LTS with official Windows Package Manager.'
      & $winget.Source install --id OpenJS.NodeJS.LTS --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
      if($LASTEXITCODE -ne 0){Warn 'winget returned an error. Existing running services are untouched.'}
      $env:Path=[Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')
      $node=FindNode
    }
  }
  if($node){Say ('Node available: '+(& $node -v))}
  else{Warn 'Node.js still unavailable. The hosted cloud MCP can still be connected through OAuth.'}
}
$python=$null
if($RequiresPython -and $NativePresent){
  $python=FindPython
  if(-not $python){
    $winget=Get-Command winget.exe -ErrorAction SilentlyContinue
    if($winget){
      Say 'Installing Python 3.12 through winget for vendor tooling (no global pip installs).'
      & $winget.Source install --id Python.Python.3.12 --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
      if($LASTEXITCODE -ne 0){Warn 'Python install did not finish; vendor offline tools may need a separate setup.'}
      $env:Path=[Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')
      $python=FindPython
    }else{Warn 'Python 3.12 is not installed; Windows App Installer (winget) required for automatic Python setup.'}
  }
  if($python){Say ('Python launcher found: '+$python)}
}
# Per-user agent configuration: never store device tokens or npm secrets here.
$cfg=@{
 service=$Service; display=$Display; mcp_url=$McpUrl; dashboard_url=$Dashboard
 install_scope='current-user'; runtime_root=$runtime; installed_at=(Get-Date).ToString('o')
 mode='hosted-connector'; native_source_detected=(Test-Path -LiteralPath $LegacySource)
}|ConvertTo-Json -Depth 3
$cfgPath=Join-Path $app 'connection.json'
Set-Content -LiteralPath $cfgPath -Value $cfg -Encoding UTF8
Say ('Shared user installation directory: '+$root)
if(Test-Path -LiteralPath $LegacySource){
  Say ('Detected native source on this computer: '+$LegacySource)
  # We do NOT restart existing vendor services, nor rewrite PM2's existing snapshot.
  $pm2=Get-Command pm2.cmd -ErrorAction SilentlyContinue
  if(-not $pm2){$pm2=Get-Command pm2 -ErrorAction SilentlyContinue}
  if($pm2){
    $desc=(& $pm2.Source describe $LegacyPm2 2>&1 | Out-String)
    if($LASTEXITCODE -eq 0 -and $desc -match [regex]::Escape($LegacyPm2)){
      Say ('Existing PM2 process found: '+$LegacyPm2+'; no duplicate will be started.')
      # A per-user startup wrapper only touches this known, pre-existing process.
      $runner=Join-Path $app 'startup.ps1'
      $pm2path=$pm2.Source.Replace("'","''")
      $process=$LegacyPm2.Replace("'","''")
      $runnerText=@'
$ErrorActionPreference='SilentlyContinue'
$pm2='__PM2_PATH__'
$name='__PM2_NAME__'
$output=& $pm2 describe $name 2>&1 | Out-String
if($LASTEXITCODE -ne 0){exit 0}
if($output -notmatch 'online') { & $pm2 restart $name | Out-Null }
'@.Replace('__PM2_PATH__',$pm2path).Replace('__PM2_NAME__',$process)
      Set-Content -LiteralPath $runner -Value $runnerText -Encoding UTF8
      $startup=[Environment]::GetFolderPath('Startup')
      if($startup){
        $lnk=Join-Path $startup ('OTOMASI MCP '+$Service+'.lnk')
        $shell=New-Object -ComObject WScript.Shell
        $shortcut=$shell.CreateShortcut($lnk)
        $shortcut.TargetPath=(Get-Command powershell.exe).Source
        $shortcut.Arguments='-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$runner+'"'
        $shortcut.WorkingDirectory=$app
        $shortcut.Description='Check existing OTOMASI '+$Service+' PM2 service on login'
        $shortcut.WindowStyle=7
        $shortcut.Save()
        Say 'Registered current-user startup check for the existing service (no SYSTEM permissions).'
      }
    }else{Warn 'PM2 process is missing: native service installation is not complete. Existing source remains unchanged.'}
  }else{Warn 'PM2 not found. Will not create an unverified daemon or duplicate vendor process.'}
}else{
  Warn 'Native backend source is not present on this computer. No native server has been installed.'
  Warn 'This installer configures the HOSTED MCP connection and user folder; vendor DLLs/DBs/app licenses are NOT redistributed.'
}
try{
 $r=Invoke-WebRequest -Uri $Health -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
 Say ('Hosted gateway health: HTTP '+[int]$r.StatusCode)
}catch{Warn 'Hosted gateway not healthy or currently unreachable. Check the service page; do not claim editor hardware is online.'}
Say ('MCP endpoint: '+$McpUrl)
Say 'Add this URL to your ChatGPT/Claude MCP connections. Authorization happens in the browser and is separate per service.'
try{Start-Process $Dashboard | Out-Null}catch{Warn 'Could not open the browser automatically; use the URL above.'}
Say 'Done: hosted connector configured; local vendor engine requires its own software and configuration.'
