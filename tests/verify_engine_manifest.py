#!/usr/bin/env python3
"""Fail-closed assertions for unreleased vendor MCP native engine packages."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
m=json.loads((root/"runtime/engines.json").read_text())
assert m["schema_version"] == 1
assert set(m["engines"]) == {"plc","easyeda","fusion"}
for slug,e in m["engines"].items():
    assert e.get("platforms"),slug
    assert e.get("runtime"),slug
    if e["release_available"]:
        assert e["broker_compatible"],f"{slug}: cannot publish without per-device routing"
        assert e.get("source_url","").startswith("https://github.com/rofiqcp/otomasi-mcp-installer-hub/releases/download/")
        assert len(e.get("sha256",""))==64
        assert e.get("version"),slug
    else:
        assert not e["broker_compatible"],f"{slug}: false broker claim"
        assert not e.get("source_url"),f"{slug}: unsigned archive must not be offered"
        assert e.get("blocker"),slug
    print("PORTABILITY_MANIFEST_VALID",slug,"RELEASE_AVAILABLE" if e["release_available"] else "BLOCKED")
s=(root/"scripts/install-native-engine.ps1").read_text(encoding="utf-8")
for term in ("broker_compatible","Get-FileHash","source_url","release_available","engine\\verify.ps1","engine\\install.ps1"):
    assert term in s,term
print("NATIVE_INSTALLER_STATIC_PASS")
