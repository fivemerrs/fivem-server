# Freeroam server features

Ephemeral ESX Legacy freeroam on GitHub Actions + Localtonet. MariaDB runs on the runner — **data resets every redeploy**.

## Connect

After a successful deploy, use the address from the workflow summary / `connect.txt`:

```
connect HOST:PORT
```

If public probe fails: Localtonet dashboard → My Tunnels → **Start** the UDP_TCP tunnel for the AuthToken, then redeploy.

## Zones (defaults)

| Zone | Script | Center | Radius | Blip |
|------|--------|--------|--------|------|
| **Green safe spawn** | `lation_greenzones` | `222.20, -864.02, 30.29` (Legion Square) | `80.0` | Green radius |
| **Red PvP** | `sd-redzones` | `106.75, -1941.19, 20.80` (Grove St) | `100.0` | Red sphere |

Green zone: no shooting, invincible, weapons removed from hand, text UI.  
Red zone: temporary loadout on enter, kill cash reward, death ejects + revives outside.

Players spawn via ESX `Config.DefaultSpawns` at the Legion green zone.

## Economy

- Starter cash: **$5000** (`money` account / ox_inventory money item)
- Redzone kill rewards: **$100–$500** (configured in `sd-redzones`)
- Paycheck disabled for this freeroam build

## Spawn hub NPCs (Legion)

| NPC | Approx coords | Action |
|-----|---------------|--------|
| Clothes | `218.5, -861.0, 30.3` | Opens `esx_skin` saveable menu |
| Gun shop | `224.0, -858.5, 30.3` | Walk-up **Freeroam Armory** marker (ox_inventory) |
| Supplies | `228.5, -856.0, 30.3` | Walk-up **Freeroam Supplies** (ammo / armour / bandage) |

Press **E** near shop markers. Clothes: press **E** at the clothing ped.

### Shop prices (approx)

**Armory:** pistol $1500, SMG $3500, carbine $5000, knife $200, bat $150 (+ ammo).  
**Supplies:** ammo-9 $25, ammo-rifle $40, armour $750, bandage $50, medikit $200.

## Stack (ensure order)

`oxmysql` → `ox_lib` → `es_extended` → `[core]` (sans `esx_inventory` / `esx_multicharacter`) → `ox_inventory` → zones → `fr_hub`

No vMenu. No Godzilla / wave-anticheat.

## Redeploy

```bash
# from workspace, with env set:
#   GH_TOKEN, LOCALTONET_AUTHTOKEN, LOCALTONET_CONNECT
python scripts/push_and_deploy.py
```

## Firebase

Not used. ESX / ox_inventory / oxmysql require MariaDB/MySQL. Firebase cannot replace that without rewriting the framework.
