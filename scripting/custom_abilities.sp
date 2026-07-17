#include <sdkhooks>
#include <sdktools>
#include <sdktools_functions>
#include <entity_prop_stocks>
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.0.0"

#define MAXENTITIES 2048
#define VSH // Comment this out if you want the abilities to work for both teams, wouldnt recommend if bosses also use similar weapons.

// HUDS
Handle TopAbilityHUD;
Handle MiddleAbilityHUD;
Handle BottomAbilityHUD;

// GlobalTimers I want to keep track of
Handle GlowTimer;

// Sprites
int beamSprite;
int haloSprite;

// Dont loop the cooldown regained sound
bool cooldownSoundPlayed[MAXPLAYERS + 1];

// States for every Weapon Slot, use accordingly.
// Also some extra guard clauses.
enum struct AbilityState
{
    bool primaryAvailable;
    bool secondaryAvailable;
    bool meleeAvailable;

    float primaryProgress;
    float secondaryProgress;
    float meleeProgress;

    float primaryCooldown;
    float secondaryCooldown;
    float meleeCooldown;

    float lockUntil;

    bool hasExplosiveArrows;
    bool hasGlowApplied;

    float healingDone;
    float glowDuration;
    int glowEntRef;

    int weaponHitStreak;
    float weaponLastHitTime;
}
AbilityState abilityState[MAXPLAYERS + 1];

// For the sake of clarity just use it depending on the weapon slot:
// Primary: Top, Secondary: Middle, Melee: Bottom
enum AbilityHudPos
{
    HUD_TOP,
    HUD_MIDDLE,
    HUD_BOTTOM
};

enum struct ProjectileState // Useful if I ever plan to do more stuff with projectiles.
{
    int lastVictim;
    int lastTick;
}
ProjectileState projectileState[MAXENTITIES];

// Precache stuff
    // General use sounds
char AbilitySoundList[][] =
{
    "weapons/vaccinator_toggle.wav",
    "items/medshotno1.wav",
    "items/medshot4.wav",
    "mvm/sentrybuster/mvm_sentrybuster_explode.wav",
};

public Plugin myinfo =
{
	name = "custom_abilities",
	author = "Latte",
	description = "Adds simple, configurable abilities to specific weapons. Trigger effects by meeting damage / healing requirements and more.",
	version = PLUGIN_VERSION,
	url = "https://github.com/normie614/custom_abilities"
};

void HandleHitStreak(int &streak, float &lastHitTime, float streakTimeout, int maxStacks, float damagePerStack, bool handleDamage = false, float &damage = 0.0)
{
    float currentTime = GetGameTime();

    if (currentTime - lastHitTime > streakTimeout)
        streak = 0;

    if (streak < maxStacks)
        streak++;

    lastHitTime = currentTime;

    if (handleDamage)
    {
        float multiplier = 1.0 + (streak * damagePerStack);
        damage *= multiplier;
    }
}

public Action Timer_GlowCheck(Handle timer) // TBH i didnt want to clutter the logic.sp with stuff not related to HUD's 'n stuff
{
    bool hasActiveGlow = false;
    for (int client = 1; client <= MaxClients; client++)
    {
        if(!IsValidClient(client) || !IsPlayerAlive(client) || !abilityState[client].hasGlowApplied)
            continue;
        if(abilityState[client].glowDuration <= 0.0)
        {
            AcceptEntityInput(abilityState[client].glowEntRef, "Kill");
            GlowTimer = null;
            abilityState[client].hasGlowApplied = false;
            abilityState[client].glowEntRef = INVALID_ENT_REFERENCE;
            abilityState[client].glowDuration = 0.0;
        }
        else
        {
            abilityState[client].glowDuration -= 0.2;
            hasActiveGlow = true;
        }
        if (!hasActiveGlow)
        {
            GlowTimer = null;
            return Plugin_Stop;
        }
    }
    return Plugin_Continue;
}

public Action Timer_Advertise(Handle timer)
{
    AdvertisePlugin();
    return Plugin_Continue;
}

#include "utils.sp"
#include "events.sp"
#include "logic.sp"