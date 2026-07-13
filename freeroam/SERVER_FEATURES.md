# Freeroam server features

Ephemeral ESX Legacy freeroam on GitHub Actions + Localtonet. MariaDB on the runner — **data resets every redeploy**.

## Connect

Use the **ADDED** address from the latest deploy (not an old dashboard port):

```
connect HOST:PORT
```

If public refuses: Localtonet → My Tunnels → **Start** the **UDP_TCP** tunnel for AuthToken **Default**, then retry.

## Zones

| Zone | Center | Radius | Notes |
|------|--------|--------|-------|
| **Green safe spawn** | `222.20, -864.02, 30.29` (Legion) | `80` | Invincible / no fire |
| **Red PvP** | `58.50, -1115.00, 29.40` (Mission Row / downtown) | `80` | ~300m from spawn; loadout + kill cash |

## World

- Ambient **NPC peds + traffic = 0** (`fr_world`)
- Spawn hub shops use **markers only** (no shop ped models). Press **E** at clothes / guns / supplies markers.

## Economy / starter

- Starter cash: **$50,000**
- Starter weapons: pistol, combat pistol, pistol mk2 + **300× ammo-9**
- Shops still sell more guns/ammo/armour/bandages

## Controls

| Key / cmd | Action |
|-----------|--------|
| **F3** | Spawn freeroam car (`kanjo` default — from your FF Menyoo pack). Deletes previous F3 car. |
| `/f3car <model>` | Select model (`kanjo`, `jester`, `remus`, …) then F3 |
| **F6** / `/team` | Teams menu (create / join / leave) |
| **E** at hub markers | Clothes / armory / supplies |

## Teams (`fr_teams`)

Lightweight custom teams (not a paid squad script): teammate blips, no friendly fire between teammates, F6 menu.

## Admin / txAdmin

- **Full txAdmin web panel** is not used on ephemeral GHA (txAdmin wraps FXServer as a separate host process; not practical here).
- Instead: ACE `group.admin` with full `command` allow.
- Set GitHub secret **`ADMIN_IDENTIFIERS`** to your id(s), comma-separated, e.g. `license:abcd1234` or `fivem:123456` (no `identifier.` prefix — the workflow adds it).
- Without that secret, nobody gets admin ACE automatically.

## Redeploy

```bash
# GH_TOKEN, LOCALTONET_AUTHTOKEN (Default), LOCALTONET_CONNECT
python scripts/push_and_deploy.py
```

## Firebase

Not used. ESX / ox_inventory need MariaDB/MySQL.
