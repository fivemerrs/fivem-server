#!/usr/bin/env bash
# Assemble ESX Legacy freeroam resources for GHA runner.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SD="$ROOT/server-data"
RES="$SD/resources"
mkdir -p "$RES" "$SD"

log() { echo "[freeroam-install] $*"; }

download_zip() {
  local url="$1" dest="$2"
  curl -fsSL -o /tmp/dl.zip "$url"
  rm -rf "$dest"
  mkdir -p "$dest"
  unzip -qo /tmp/dl.zip -d /tmp/dl_extract
  # unwrap single top-level folder if present
  local top
  top="$(find /tmp/dl_extract -mindepth 1 -maxdepth 1 -type d | head -n1)"
  if [ -n "$top" ] && [ "$(find /tmp/dl_extract -mindepth 1 -maxdepth 1 | wc -l)" -eq 1 ]; then
    cp -a "$top"/. "$dest"/
  else
    cp -a /tmp/dl_extract/. "$dest"/
  fi
  rm -rf /tmp/dl_extract /tmp/dl.zip
}

log "FXServer artifact"
curl -fsSL -o /tmp/fx.tar.xz \
  "https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/25770-8ddccd4e4dfd6a760ce18651656463f961cc4761/fx.tar.xz"
mkdir -p "$ROOT/fxserver"
tar -xf /tmp/fx.tar.xz -C "$ROOT/fxserver"

log "cfx-server-data (defaults)"
curl -fsSL -o /tmp/cfx.zip https://github.com/citizenfx/cfx-server-data/archive/refs/heads/master.zip
unzip -qo /tmp/cfx.zip -d /tmp
cp -a /tmp/cfx-server-data-master/resources/. "$RES"/

log "ESX Legacy core 1.13.4"
curl -fsSL -o /tmp/esx.zip https://github.com/esx-framework/esx_core/releases/download/1.13.4/esx_core.zip
unzip -qo /tmp/esx.zip -d /tmp/esx
# zip layout: .../esx_core/[core]/es_extended
ESX_DIR="$(find /tmp/esx -maxdepth 4 -type d -name es_extended | head -n1)"
ESX_ROOT="$(dirname "$(dirname "$ESX_DIR")")"
log "ESX_ROOT=$ESX_ROOT"
rm -rf "$RES/[core]"
cp -a "$ESX_ROOT/[core]" "$RES/[core]"
mkdir -p "$SD/sql"
cp -a "$ESX_ROOT/[SQL]/." "$SD/sql/"

# Drop conflicting / heavy core pieces for freeroam
rm -rf "$RES/[core]/esx_inventory" \
       "$RES/[core]/esx_multicharacter" \
       "$RES/[core]/esx_loadingscreen"

log "oxmysql / ox_lib / ox_inventory"
download_zip "https://github.com/overextended/oxmysql/releases/download/v2.14.1/oxmysql.zip" "$RES/oxmysql"
download_zip "https://github.com/overextended/ox_lib/releases/download/v3.39.0/ox_lib.zip" "$RES/ox_lib"
download_zip "https://github.com/overextended/ox_inventory/releases/download/v2.47.9/ox_inventory.zip" "$RES/ox_inventory"

log "lation_greenzones"
download_zip "https://github.com/IamLation/lation_greenzones/archive/refs/heads/main.zip" "$RES/lation_greenzones"

log "sd-redzones"
download_zip "https://github.com/Samuels-Development/sd-redzones/archive/refs/heads/main.zip" "$RES/sd-redzones"

log "Apply freeroam overlays"
cp -f "$ROOT/freeroam/overlays/es_extended/shared/config/main.lua" \
  "$RES/[core]/es_extended/shared/config/main.lua"
cp -f "$ROOT/freeroam/overlays/lation_greenzones/config.lua" \
  "$RES/lation_greenzones/config.lua"
cp -f "$ROOT/freeroam/overlays/sd-redzones/config.lua" \
  "$RES/sd-redzones/config.lua"
cp -f "$ROOT/freeroam/overlays/ox_inventory/data/shops.lua" \
  "$RES/ox_inventory/data/shops.lua"
cp -f "$ROOT/freeroam/patches/sd-redzones-client.lua" \
  "$RES/sd-redzones/client/main.lua"

# Wire bandage/armour usable exports
python3 - <<'PY'
from pathlib import Path
p = Path("server-data/resources/ox_inventory/data/items.lua")
text = p.read_text(encoding="utf-8")
if "fr_hub.useBandage" not in text:
    text = text.replace(
        "['bandage'] = {\n\t\tlabel = 'Bandage',\n\t\tweight = 115,\n\t\tclient = {",
        "['bandage'] = {\n\t\tlabel = 'Bandage',\n\t\tweight = 115,\n\t\tclient = {\n\t\t\texport = 'fr_hub.useBandage',",
        1,
    )
if "fr_hub.useArmour" not in text:
    text = text.replace(
        "['armour'] = {\n\t\tlabel = 'Bulletproof Vest',\n\t\tweight = 3000,\n\t\tstack = false,\n\t\tclient = {",
        "['armour'] = {\n\t\tlabel = 'Bulletproof Vest',\n\t\tweight = 3000,\n\t\tstack = false,\n\t\tclient = {\n\t\t\texport = 'fr_hub.useArmour',",
        1,
    )
p.write_text(text, encoding="utf-8")
print("patched ox_inventory items exports")
PY

log "Copy fr_hub"
cp -a "$ROOT/freeroam/resources/fr_hub" "$RES/fr_hub"

# Improve redzone ammo counts in server loadout
python3 - <<'PY'
from pathlib import Path
p = Path("server-data/resources/sd-redzones/server/main.lua")
text = p.read_text(encoding="utf-8")
old = """for _, item in ipairs(Config.LoadoutItems) do
        AddItem(src, item, 1)
        table.insert(playerLoadouts[identifier], item)
    end"""
new = """for _, item in ipairs(Config.LoadoutItems) do
        local count = 1
        if type(item) == 'table' then
            count = item.count or 1
            item = item.name
        elseif tostring(item):find('ammo', 1, true) then
            count = 120
        end
        AddItem(src, item, count)
        table.insert(playerLoadouts[identifier], item)
    end"""
if old in text:
    p.write_text(text.replace(old, new), encoding="utf-8")
    print("patched sd-redzones loadout counts")
else:
    print("WARN: loadout loop not patched (format changed)")
PY

log "Resource tree (depth 2)"
find "$RES" -maxdepth 2 -type d | head -n 80

log "done"
