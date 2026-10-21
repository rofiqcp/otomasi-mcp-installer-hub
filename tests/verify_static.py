from pathlib import Path
base=Path(__file__).resolve().parents[1]
for name in ('plc','easyeda','fusion'):
 page=(base/'portal'/f'{name}.html').read_text(encoding='utf-8')
 script=(base/'scripts'/f'{name}.ps1').read_text(encoding='utf-8')
 assert f'/install/{name}.ps1' in page
 assert f'/api/service-health/{name}' in page
 assert 'Set-Content' in script and 'LOCALAPPDATA' in script
 assert 'OTOMASI_INSTALL_DRY_RUN' in script
 assert '$NativePresent' in script
 assert 'Test-Path -LiteralPath $LegacySource' in script
 assert 'MCP endpoint' in script
 assert 'Get-Command pm2' in script
 assert 'Restart-Service' not in script and 'Stop-Service' not in script
 assert 'PLC download' not in script
 print('STATIC_OK',name)
for f in ('catalog.css','catalog.js'):
 assert (base/'portal'/f).stat().st_size>300
print('VERIFIED_PORTAL_ASSETS')
