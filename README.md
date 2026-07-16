# Custom Abilities

A configurable Team Fortress 2 SourceMod plugin that aims to reimagine existing weapons by giving them new mechanics, alternative firing modes and unique abilities.

> **Current Version:** `1.0.0`

> **Status:** First public release. While the plugin should be fully playable, bugs and balance issues are expected.
---

# Features

* Overhauls several stock TF2 weapons with completely new mechanics.
* Every ability can be individually enabled or disabled.
* Nearly every value is configurable through ConVars.
* Automatically generates a configuration file on first launch.
* Designed to be modular, making future weapon additions straightforward.

---

# Installation

1. Install the latest version of **SourceMod**.
2. Copy `custom_abilities.smx` into:

```
addons/sourcemod/plugins/
```

3. Start or change the map.

The plugin will automatically generate:

```
cfg/sourcemod/custom_abilities.cfg
```

This file contains every available ConVar, allowing server owners to customize or disable individual mechanics without recompiling the plugin.

---

# Compilation

1. Compile using **SourcePawn 1.12** or newer.
2. Install the required dependency:
   - [TF2Attributes](https://github.com/FlaminSarge/tf2attributes)

# Weapon Changes

## Scout

### Sandman

* Optional stun effect.

### Crit-a-Cola

* Grants full critical hits instead of Mini-Crits.

### Sun-on-a-Stick

* Build up damage to unlock a throwable fireball.

---

## Soldier

*(No custom abilities in this release.)*

---

## Pyro

*(No custom abilities in this release.)*

---

## Demoman

### Grenade Launcher

The Grenade Launcher supports three selectable firing modes:

- **Rounds**
  - Standard firing mode with an increased firing speed.

- **Spray**
  - Fires the entire clip simultaneously in a spread pattern.

- **Charge**
  - Launches every loaded grenade at once in a single burst.

### Iron Bomber

* Consecutive pipe hits increase damage.
* Configurable maximum stacks.
* Configurable damage per stack.
* Configurable timeout before the streak resets.
* Can optionally count splash damage or direct hits only.

---

## Heavy

### Family Business

Introduces the **Fat Scout** subclass.

Features include:

* Increased movement speed.
* Lifesteal on shotgun damage.
* Configurable overheal limit.
* Fully configurable movement and healing values.

---

## Engineer

### Pomson 6000

* Projectile penetration.
* Knockback on hit.
* Airshot streak mechanic that rewards juggling opponents.
* Includes a fix preventing the same penetrating projectile from damaging the same player multiple times.

### Engineer (General)
### Pistols
* Optional movement before the round starts.
* Configurable pre-round movement speed.

### Sentry Guns

* Optional glow effect applied by Sentries, Mini-Sentries, or both.
* Configurable glow duration and maximum reveal time.

---

## Medic
Damage / Healing requirements and cooldowns are fully configurable.
### Crusader's Crossbow

* Explosive arrows unlocked after dealing enough damage.

### Medigun

* Periodically grants throwable healing grenades.

### Quick-Fix

* Personal Mini-Uber earned through healing teammates.

### Vaccinator

* Deployable defensive shield with configurable cooldown.
* Optional enemy knockback.

---

## Sniper

### Huntsman

* Airshots above a configurable height threshold deal increased damage.
* Configurable threshold and damage multiplier.

---

## Spy

### Diamondback

* Fires rockets instead of bullets.
* Starting rocket ammunition is configurable.
* Ammo can optionally be earned through backstabs instead of pickups.
* Optional enhanced jump and air control.

### Sapper

* Turns the Spy into a timed kamikaze explosive.

### Knives

* Throw your equipped knife.
* Different knives apply different effects depending on the weapon being thrown.
* Configurable cooldown before the knife returns.

---

# Configuration

Every mechanic can be configured through ConVars.

The plugin automatically creates:

```
cfg/sourcemod/custom_abilities.cfg
```

Server owners can:
* Enable weapon for both teams (comment out #define vsh).
* Enable or disable individual weapon abilities.
* Adjust cooldowns.
* Modify damage values.
* Tune movement speeds.
* Configure healing.
* Change stack limits.
* Adjust knockback.
* Control airshot requirements.
* Customize many other gameplay values.

The thrown knife system is highly customizable. If you wish to change damage values, bleed duration, or the effects applied by each knife, edit:

```
addons/sourcemod/scripting/custom_abilities/mechanics/throwing_knives.sp
```

---

# Notes

* This is the **first public release (1.0.0)**.
* Balance is expected to evolve over future releases.
* Suggestions for new abilities and balance changes are always welcome.

---

# Credits

Created by **Latte**, with ability concepts by **Nokwed**.

Big thanks to the **SourceMod** and **AlliedModders** communities — this project wouldn't have been possible without their docs, plugins, and forum threads to learn from.

---