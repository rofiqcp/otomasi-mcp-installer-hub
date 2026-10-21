# OTOMASI MCP — AI prompt playbook

## All new MCPs
1. Verify the **actual** MCP endpoint and OAuth granted scope, never assume write privileges from a read-only connection.
2. Select exact target service, project, model, document and mode (e.g. EasyEDA GLOBAL vs JLC China).
3. Read official local skill / MCP Resources / tool help BEFORE creating or editing data.
4. Plan a bounded operation and identify destructive/hardware interactions. Never silently upgrade permissions.
5. Make a recoverable backup/version copy where supported. Apply modifications only with verified matching IDs, model/firmware, and user scope.
6. Read back and validate native results, run DRC/ERC or WCP validation or Fusion geometry audit as appropriate.
7. Report each result as observed/failed/unverified. Don't claim rendering, cloud synchronization, editor GUI status or hardware operation without proof.

## PLC WECON
Read `plc_ai_instructions`, `plc_status`, `plc_permissions`, `plc_hardware_preflight`. Keep 150 vendor module originals read-only. Work only on explicit workspace copies. Check SHA256 and vendor native validation, compare IL. Physical PLC download/upload/forced I/O is disabled until bench preflight, backup/readback, explicit operator approval and supported transport. Never enable machine hardware from installer.

Sample:
> Pilih WECON LX3V dengan proyek WCP yang saya tentukan. Baca semua IL asli, buat clone workspace, verifikasi ladder dan checksum, lalu bandingkan hasilnya tanpa upload/download fisik.

## EasyEDA Pro
Read `easyeda_panduan`, `easyeda_cad_native_panduan`, `easyeda_diagnostik_akses`. Distinguish EasyEDA GLOBAL and China/JLC region explicitly. Validate active native project, schematic netlist, component LCSC footprint and PCB DRC/ERC. No cross-region mutation. Explicit manual approval for potentially damaging scripts.

Sample:
> Audit proyek EasyEDA GLOBAL yang sedang aktif. Baca schematic, netlist, footprint, PCB, dan izin sesi. Laporkan DRC/ERC, buat rencana rapi industrial, lalu tampilkan perubahan yang akan disetujui sebelum menyimpan.

## Autodesk Fusion
Use `fusion_mcp_read` to identify current document and user-visible geometry, then `fusion_mcp_execute`/`fusion_mcp_update` only after confirming exact document and requested feature. Check native Fusion desktop running on configured MCP port (WIN-OTO 27183) and cloud authentication, inspect before/after CAD geometry and screenshots. Do not claim full Fusion Cloud CRUD or CAD upload without actual live verification.

Sample:
> Baca dokumen aktif dan spesifikasi assembly di Autodesk Fusion, verifikasi satuan/dimensi, ubah hanya sketch/feature yang saya sebut, inspect screenshot, lalu simpan setelah semua parameter benar.

## Publication checklist
Do not publish existing WIN-OTO server sources or databases directly. Native distribution first requires a self-contained source-only refactor, third-party license review, explicit OAuth tenant isolation, no embedded credentials, vendor prereq detection, recovery mechanism, startup isolation and real clean VM tests. Only THEN create public GitHub + npm packages with Trusted Publishing OIDC, and publish separate agents per service.
