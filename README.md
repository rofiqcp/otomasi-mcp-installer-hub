# OTOMASI MCP Installer Hub

Public onboarding/installer frontend for the three existing Windows-native MCP integrations:
**WECON PLC, EasyEDA Pro and Autodesk Fusion**. The canonical live API endpoints
continue to be managed by their independently authenticated gateway servers.

## Live website
| Service | Hub page | MCP URL | Native host |
|---|---|---|---|
| PLC | https://mcp.otomasi.app/plc | https://mcp-plc.otomasi.app/mcp | WIN-OTO |
| EasyEDA | https://mcp.otomasi.app/easyeda | https://easyeda.otomasi.app/mcp | WIN-OTO |
| Fusion | https://mcp.otomasi.app/fusion | https://autodesk.otomasi.app/mcp | WIN-OTO |

## Public Windows commands

```powershell
irm https://mcp.otomasi.app/install/plc.ps1 | iex
irm https://mcp.otomasi.app/install/easyeda.ps1 | iex
irm https://mcp.otomasi.app/install/fusion.ps1 | iex
```

**User warning:** Executing remote scripts should only be done after inspecting the source at the URLs above. These commands are for Windows and do **not** clone/deploy the native server code, vendor licensed applications, database contents, PLC DLLs or OAuth secrets. New Windows users connecting ChatGPT/Claude to the hosted MCP URL do **not need to install any local backend or Node/Python**.

### Shared installation root
- Windows per-user: `%LOCALAPPDATA%\OTOMASI\MCP\agents\{plc,easyeda,fusion}`
- Windows shared runtime folder: `%LOCALAPPDATA%\OTOMASI\MCP\runtime`
- Current-user startup: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\OTOMASI MCP <service>.lnk` (only if a matching **preinstalled and registered** native PM2 process exists)
- Ubuntu future per-user layout: `~/.local/share/otomasi/mcp/agents/<service>`
- macOS future per-user layout: `~/Library/Application Support/OTOMASI/MCP/agents/<service>`

This design intentionally does **not** write into `C:\Program Files` as elevation is not required for a per-user install. Existing WIN-OTO source trees remain at `C:\riset\mcp\{PLC,easyeda,autodesk}`—no forced migration or service restart.

### Language runtimes
- PLC: Node 22+ and Python >=3.10 when the Windows native server source is already present.
- EasyEDA: Node 22+ when the source is present, plus vendor/editor bridge and PostgreSQL. No automatic PG bootstrap.
- Fusion: Python >=3.10 when source is present and Autodesk Fusion native MCP configured. Autodesk installation/licensing remains external.
- Missing runtime on Windows with a detected source: official `winget OpenJS.NodeJS.LTS` / `Python.Python.3.12` installation is attempted. Do not assume that runtime acquisition proves native backend can execute.
- If source is **absent**, do NOT install unused runtimes. Set up the hosted MCP link and open the browser; the local vendor service remains unavailable.

### Safety and startup
- The installer never issues hardware PLC download/force, never edits PCB/CAD design, and never creates a token.
- Source tree and existing PM2 processes are inspected. No cloned private vendor engine, no PM2 duplicate, no direct hardware action.
- A startup shortcut is created only when the corresponding native source and known PM2 process both exist. It checks/restarts **only** that named process if offline at next login, without changing other PM2 apps/snapshots.
- PLC hardware tool calls have separate OAuth scope and are disabled in the native backend as documented; startup of a gateway does not activate physical operations.
- EasyEDA GLOBAL and China/JLC editors are separate; no automatic cross-region project mutation.
- Fusion native engine must be running; a healthy OAuth gateway alone does not mean native Fusion MCP is usable.

### API/portal separation
- The main MCP Hub runs on `/home/sirobo/mcp/remote-pc-mcp`.
- This repository in `/home/sirobo/mcp/installer-hub` holds ONLY three public onboarding static pages, scripts, tests, and documentation.
- Runtime routes in production are registered within the *private* main gateway at `/home/sirobo/mcp/remote-pc-mcp/dashboard.py`, which intentionally is **not** part of the public installer repository.
- The portal uses a whitelist-only `/api/service-health/{plc,easyeda,fusion}` endpoint, returning simple health status; avoids exposing private vendor health payloads.
- Anonymous access to `/mcp` and `/office/mcp` must remain 401; new service MCP endpoints remain individually protected on their original hostnames.

## User workflow
1. Open the hub page; inspect its status, requirements, and link to hosted endpoint.
2. Copy the MCP URL into ChatGPT/Claude settings and authenticate with the vendor-specific OAuth in the browser.
3. On the actual WIN-OTO host where native source exists, optionally run the Windows setup command to standardize local runtime checks, per-user config, and startup.
4. Test read-only first. Request additional write/delete permissions intentionally. Never use an MCP prompt to bypass hardware safety.
5. Keep the vendor desktop application online for native CAD functionality.

## Regression and scope
- `tests/test_catalog.py`: tests production gateway ASGI route outcomes (requires the private remote-pc-mcp project). Not suitable for running standalone from the public GitHub repository.
- Public web/PowerShell dry-run: Windows PS syntax and dry-run passed for all three.
- Actual WIN-OTO install: all three scripts generated folders and per-user startup shortcuts. PLC/EasyEDA were healthy; Fusion health was HTTP 503 due native Fusion engine not ready.
- Desktop+mobile Chromium screenshots manually inspected.

### Not yet implemented
- Distributable **native backend packages** `@otomasi/plc`, `@otomasi/easyeda`, `@otomasi/fusion` published to npm. Current backends contain vendor dependencies and sensitive state and are not safe to copy/publish directly.
- Clean-room Windows install of all vendor applications and managed PostgreSQL.
- Native backend installs on Ubuntu/macOS: no verified compatible release for the current WIN-OTO integrations.
- Automatic source migration from `C:\riset\mcp` into `%LOCALAPPDATA%`: do not move running vendor instances until backups, config path adjustments and acceptance tests are done.

See `docs/AI-PROMPTS.md` for safe per-service AI workflows and limitations.
