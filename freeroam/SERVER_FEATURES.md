# Freeroam server features

Ephemeral ESX Legacy freeroam on GitHub Actions + Localtonet. MariaDB on the runner — **data resets every redeploy**.

## Connect

**Easiest:** double-click `Start-FiveM-Server.bat` (see [`START_SERVER.md`](../START_SERVER.md)). Fill local `fivem-launcher.env` with `GH_TOKEN` + optional `LOCALTONET_API_KEY` — never commit that file.

Or use the **ADDED** address from the latest deploy (not an old dashboard port):

```
connect HOST:PORT
```

If public refuses: Localtonet → My Tunnels → **Start** the **UDP_TCP** tunnel for AuthToken **Default**, then retry. With a Dashboard **ApiKey**, the launcher can Start the tunnel via API automatically.

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

## F3 car (Fast & Furious 1 lore pack)

The [GTA5-Mods pack](https://www.gta5-mods.com/vehicles/fast-furious-1-lore-friendly-car-pack-diablo317) is a **21KB Menyoo XML preset pack for vanilla GTA vehicles** — it is **not** a streamed addon (no `.yft`/`.ytd`). FiveM cannot “install” it as a stream resource.

**F3** spawns **Dom’s Charger stand-in: `dukes`**, with mods from `FF1 Dukes.xml` (black custom paint, turbo, performance mods).

| Key / cmd | Action |
|-----------|--------|
| **F3** | Spawn current Fast1 car (default `dukes`). Deletes previous F3 car. |
| `/f3car penumbra` | Brian’s Eclipse stand-in |
| `/f3car jester` | Supra stand-in |
| `/f3car remus` / `kanjo` | Letty Silvia stand-ins |

Optional accurate addons linked in the pack readme (Kanjo SJ / Jester Classic) are separate downloads — not bundled.

## Teams (`fr_teams`)

Lightweight custom teams: **F6** / `/team` — create/join/leave, teammate blips, no friendly fire between teammates.

## Admin / txAdmin

- **Full txAdmin web panel** is not used on ephemeral GHA (txAdmin wraps FXServer as a host process).
- ACE `group.admin` with full `command` allow.
- Set GitHub secret **`ADMIN_IDENTIFIERS`** to your id(s), e.g. `license:abcd1234` or `fivem:123456`.
- Without that secret, nobody gets admin ACE automatically.

## Redeploy

```bash
# GH_TOKEN, LOCALTONET_AUTHTOKEN (Default), LOCALTONET_CONNECT
python scripts/push_and_deploy.py
```

## Firebase

Not used. ESX / ox_inventory need MariaDB/MySQL.
