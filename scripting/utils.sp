// Most of this stuff is borrowed from Nosoop's stocksoup. This file is for ease of compilation.
#include "abilities/scout.sp"
#include "abilities/demoman.sp"
#include "abilities/heavy.sp"
#include "abilities/engineer.sp"
#include "abilities/medic.sp"
#include "abilities/sniper.sp"
#include "abilities/spy.sp"
#include "abilities/mechanics/throwing_knives.sp"
static const float OFF_THE_MAP[3] = { 16383.0, 16383.0, -16383.0 };

enum SolidFlags_t //m_usSolidFlags
{
    FSOLID_CUSTOMRAYTEST        = 0x0001,    // Ignore solid type + always call into the entity for ray tests
    FSOLID_CUSTOMBOXTEST        = 0x0002,    // Ignore solid type + always call into the entity for swept box tests
    FSOLID_NOT_SOLID            = 0x0004,    // Are we currently not solid?
    FSOLID_TRIGGER                = 0x0008,    // This is something may be collideable but fires touch functions
                                            // even when it's not collideable (when the FSOLID_NOT_SOLID flag is set)
    FSOLID_NOT_STANDABLE        = 0x0010,    // You can't stand on this
    FSOLID_VOLUME_CONTENTS        = 0x0020,    // Contains volumetric contents (like water)
    FSOLID_FORCE_WORLD_ALIGNED    = 0x0040,    // Forces the collision rep to be world-aligned even if it's SOLID_BSP or SOLID_VPHYSICS
    FSOLID_USE_TRIGGER_BOUNDS    = 0x0080,    // Uses a special trigger bounds separate from the normal OBB
    FSOLID_ROOT_PARENT_ALIGNED    = 0x0100,    // Collisions are defined in root parent's local coordinate space
    FSOLID_TRIGGER_TOUCH_DEBRIS    = 0x0200,    // This trigger will touch debris objects

    FSOLID_MAX_BITS    = 10
};
enum SolidType_t //m_nSolidType
{
	SOLID_NONE			= 0,	// no solid model
	SOLID_BSP			= 1,	// a BSP tree
	SOLID_BBOX			= 2,	// an AABB
	SOLID_OBB			= 3,	// an OBB (not implemented yet)
	SOLID_OBB_YAW		= 4,	// an OBB, constrained so that it can only yaw
	SOLID_CUSTOM		= 5,	// Always call into the entity for tests
	SOLID_VPHYSICS		= 6,	// solid vphysics object, get vcollide from the model and collide with that
	SOLID_LAST,
};
enum Collision_Group_t //m_CollisionGroup
{
    COLLISION_GROUP_NONE  = 0,
    COLLISION_GROUP_DEBRIS,            // Collides with nothing but world and static stuff
    COLLISION_GROUP_DEBRIS_TRIGGER, // Same as debris, but hits triggers
    COLLISION_GROUP_INTERACTIVE_DEBRIS,    // Collides with everything except other interactive debris or debris
    COLLISION_GROUP_INTERACTIVE,    // Collides with everything except interactive debris or debris
    COLLISION_GROUP_PLAYER,
    COLLISION_GROUP_BREAKABLE_GLASS,
    COLLISION_GROUP_VEHICLE,
    COLLISION_GROUP_PLAYER_MOVEMENT,  // For HL2, same as Collision_Group_Player, for
                                        // TF2, this filters out other players and CBaseObjects
    COLLISION_GROUP_NPC,            // Generic NPC group
    COLLISION_GROUP_IN_VEHICLE,        // for any entity inside a vehicle
    COLLISION_GROUP_WEAPON,            // for any weapons that need collision detection
    COLLISION_GROUP_VEHICLE_CLIP,    // vehicle clip brush to restrict vehicle movement
    COLLISION_GROUP_PROJECTILE,        // Projectiles!
    COLLISION_GROUP_DOOR_BLOCKER,    // Blocks entities not permitted to get near moving doors
    COLLISION_GROUP_PASSABLE_DOOR,    // Doors that the player shouldn't collide with
    COLLISION_GROUP_DISSOLVING,        // Things that are dissolving are in this group
    COLLISION_GROUP_PUSHAWAY,        // Nonsolid on client and server, pushaway in player code

    COLLISION_GROUP_NPC_ACTOR,        // Used so NPCs in scripts ignore the player.
    COLLISION_GROUP_NPC_SCRIPTED,    // USed for NPCs in scripts that should not collide with each other

    LAST_SHARED_COLLISION_GROUP
}; 

stock void UTIL_MakeGameEventHooks()
{
	HookEvent("teamplay_round_start", EventRoundStart, EventHookMode_PostNoCopy)
	//HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("player_spawn", EventPlayerSpawn, EventHookMode_Post);
	HookEvent("post_inventory_application", EventInventoryApplicationPost, EventHookMode_Post);
	HookEvent("player_healed", EventPlayerHealed, EventHookMode_Post);
}

stock void UTIL_HookExistingClients()
{
	for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client))
        {
            SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
			SDKHook(client, SDKHook_WeaponCanSwitchTo, OnWeaponCanSwitchTo);
        }
    }
}

stock void UTIL_MakeHUDS()
{
	TopAbilityHUD = CreateHudSynchronizer();
	MiddleAbilityHUD = CreateHudSynchronizer();
	BottomAbilityHUD = CreateHudSynchronizer();
}

stock void UTIL_MakeConVars()
{
	cvarShouldSandmanStun = CreateConVar("sm_ca_sandman_stun", "1.0", "Whether the Sandman can stun enemies.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarCritacolaGivesCrits = CreateConVar("sm_ca_critacola_crits", "1.0", "Whether the Critacola should give crits intead of mini-crits.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarSunOnAStickAbility = CreateConVar("sm_ca_sun_stick_fireball", "1.0", "Whether the Sun On A Stick has the fireball ability.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarGrenadeLauncherHasModes = CreateConVar("sm_ca_grenadelauncher_has_modes", "1.0", "Whether the Grenade Launcher has alternative shooting modes.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarIronBomberHasHitStreak = CreateConVar("sm_ca_iron_bomber_hit_streak_enabled", "1.0", "Whether the Iron Bomber's consecutive hit streak damage bonus is enabled.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarFamilyBusinessIsFatScout = CreateConVar("sm_ca_family_business_is_fatscout", "1.0", "Enables the Fat Scout sub-class for the Family Business Heavy.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarPomsonHasPenetration = CreateConVar("sm_ca_pomson_has_penetration", "1.0", "Whether the Pomson projectiles penetrates players | Fixed: Players being hit multiple times by the same projectile).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarPomsonHasKnockback = CreateConVar("sm_ca_pomson_has_knockback", "1.0", "Whether the Pomson applies knockback on hit.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarPomsonHasAirshotStreak = CreateConVar("sm_ca_pomson_has_airshot_streak", "1.0", "Wheter airshotting with the Pomson gives stacks, increasing damage | Airshot threshold is the same as the one for the huntsman.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarSentryGlowType = CreateConVar("sm_ca_sentry_glow_type", "2.0", "Which sentry types apply glow. 0 = Disabled, 1 = Sentry, 2 = Mini-Sentry, 3 = Both.", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	cvarCrossbowAbility = CreateConVar("sm_ca_crossbow_explosives", "1.0", "Whether the Crossbow has the explosives ability.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarMedigunAbility = CreateConVar("sm_ca_medigun_healing_grenade", "1.0", "Whether the Medigun gives healing grenades periodically.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarQuickFixAbility = CreateConVar("sm_ca_quickfix_mini_uber", "1.0", "Whether the Quick-Fix can activate a mini personal uber after certain healing done", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarVaccinatorAbility = CreateConVar("sm_ca_vaccinator_shield", "1.0", "Whether the Vaccinator can activate a shield based on cooldown", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarHuntsmanAbility = CreateConVar("sm_ca_huntsman_airshots", "1.0", "Whether airshoting with the bow above a certain height threshold causes more damage.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarDiamondBackAbility = CreateConVar("sm_ca_diamondback_rockets", "1.0", "Whether the Diamondback has rockets as ammo.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarSapperKamikazeAbility = CreateConVar("sm_ca_sapper_is_kamikaze", "1.0", "Allows the player to explode after a brief period of time and cause damage around him.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarKnifeThrowAbility = CreateConVar("sm_ca_knife_is_throwable", "1.0", "Allows the player to throw his knife.", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	cvarHealingGrenadeDuration = CreateConVar("sm_ca_healing_grenade_duration", "10.0", "Time before the grenade stops healing.", FCVAR_NOTIFY);
	cvarHealingGrenadeHealDelay = CreateConVar("sm_ca_healing_grenade_delay", "1.0", "Time between each healing tick from the healing grenade.", FCVAR_NOTIFY);
	cvarHealingGrenadeHealAmount = CreateConVar("sm_ca_healing_grenade_heal_amount", "25.0", "Amount of health restored per healing tick.", FCVAR_NOTIFY);
	cvarHealingGrenadeOverhealAmount = CreateConVar("sm_ca_healing_grenade_overheal_amount", "0.0", "Amount of overheal the user receives.", FCVAR_NOTIFY);
	cvarHealingGrenadeCooldown = CreateConVar("sm_ca_healing_grenade_cooldown", "30.0", "Cooldown before you regain the grenade.", FCVAR_NOTIFY);

	cvarIronBomberHitStreakTimeout = CreateConVar("sm_ca_iron_bomber_streak_timeout", "5.0", "Time in seconds since the last pipe hit before the Iron Bomber's streak resets.", FCVAR_NOTIFY, true, 0.0);
	cvarIronBomberMaxStacks = CreateConVar("sm_ca_iron_bomber_max_stacks", "5.0", "Maximum number of consecutive hit stacks the Iron Bomber's damage bonus can reach.", FCVAR_NOTIFY, true, 0.0);
	cvarIronBomberDamagePerStack = CreateConVar("sm_ca_iron_bomber_damage_per_stack", "0.05", "Damage multiplier increase per consecutive hit stack (e.g. 0.05 = +5% damage per stack).", FCVAR_NOTIFY, true, 0.0);
	cvarIronBomberStacksWithSplash = CreateConVar("sm_ca_iron_bomber_stacks_with_splash", "0.0", "Whether a single Iron Bomber projectile can grant multiple stacks by damaging multiple enemies. Disabled = Direct hits only; Enabled = Count every enemy damaged.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarFatScoutSpeedBuff = CreateConVar("sm_ca_fatscout_speed_buff", "1.0", "Movement speed multiplier. 1.0 = default speed, 1.15 = 15% faster.", FCVAR_NOTIFY, true, 0.1, true, 3.0);
	cvarFatScoutOverheal = CreateConVar("sm_ca_fatscout_overheal", "50.0", "Maximum additional overheal amount granted by lifesteal.", FCVAR_NOTIFY, true, 0.0, true, 500.0);
	cvarFatScoutLifesteal = CreateConVar("sm_ca_fatscout_lifesteal", "80.0", "Maximum health gained from shotgun damage.", FCVAR_NOTIFY, true, 0.0, true, 500.0);
	cvarPomsonKnockbackVertical = CreateConVar("sm_ca_pomson_knockback_vertical", "500.0", "Vertical knockback force applied when a player is hit by the Pomson.", FCVAR_NOTIFY);
	cvarPomsonKnockbackHorizontal = CreateConVar("sm_ca_pomson_knockback_horizontal", "-200.0", "Horizontal knockback force applied when a player is hit by the Pomson.", FCVAR_NOTIFY);
	cvarPomsonDamagePerStack = CreateConVar("sm_ca_pomson_damage_per_stack", "0.1","Damage multiplier increase per consecutive airshot hit stack (e.g. 0.05 = +5% damage per stack).", FCVAR_NOTIFY, true, 0.0);
	cvarSentryMaxGlowTime = CreateConVar("sm_ca_sentry_max_glow_time", "5.0", "Cap for how long a sentry can leave you revealed using glow.", FCVAR_NOTIFY);
	cvarSentryGlowTimeToAdd = CreateConVar("sm_ca_sentry_glow_time_to_add", "0.2", "Glow duration added for each sentry hit.", FCVAR_NOTIFY);
	cvarMedicShieldShouldPush = CreateConVar("sm_ca_vaccinator_shield_should_push", "1.0", "Whether the Vaccinator shield should push enemies away.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarMedicShieldCooldown = CreateConVar("sm_ca_vaccinator_shield_cooldown", "70.0", "Whether the Vaccinator shield should push enemies away.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarHuntsmanMinHeightForAirshot = CreateConVar("sm_ca_huntsman_min_height_for_airshot", "100.0", "Height threshold for the hit to count as an airshot.", FCVAR_NOTIFY);
	cvarHuntsmanAirshotDamageMultiplier = CreateConVar("sm_ca_huntsman_airshot_damage_multiplier", "2.0", "Multiplier for the damage done after hitting an airshot.", FCVAR_NOTIFY);
	cvarDiamondbackStartingClip = CreateConVar("sm_ca_diamondback_starting_clip", "4.0", "Starting rocket clip size for the Spy (if picking up ammo packs are disabled; backstabs gives ammo)", FCVAR_NOTIFY);
	cvarDiamondbackAllowAmmoPickup = CreateConVar("sm_ca_diamonback_allow_ammo_pickup", "0.0", "Whether the Diamondback user can pickup ammo packs", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarDiamondbackAmmoToGive = CreateConVar("sm_ca_diamondback_ammo_to_give", "2.0", "Amount of ammo the user gets per backstab.", FCVAR_NOTIFY);
	cvarDiamondbackEnhancedJump = CreateConVar("sm_ca_diamondback_has_enhanced_jump", "1.0", "Whether the Diamondback user should have better jump and aircontrol", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarKamikazeExplosionRange = CreateConVar("sm_ca_kamikaze_explosion_range", "250.0", "Explosion range in hammer units.", FCVAR_NOTIFY, true, 0.0);
	cvarKamikazeExplosionDamage = CreateConVar("sm_ca_kamikaze_explosion_damage", "1000", "Damage dealt by the kamikaze explosion.", FCVAR_NOTIFY, true, 0.0);
	cvarKamikazeTimeBeforeExplosion = CreateConVar("sm_ca_kamikaze_time_before_explosion", "2.0", "Time before the Spy explodes", FCVAR_NOTIFY, true, 0.0);
	cvarKamikazeRunSpeed = CreateConVar("sm_ca_kamikaze_run_speed", "500.0", "Once the explosion timer starts, the user runs at this speed.", FCVAR_NOTIFY);
	cvarKnifeThrowAbilityCooldown = CreateConVar("sm_ca_knife_throw_cooldown", "10.0", "Cooldown before the user gets back his knife.", FCVAR_NOTIFY, true, 0.0);

	cvarShouldEngineerMoveOnPreround = CreateConVar("sm_ca_allow_engineer_early_move", "1.0", "Whether the engineer should be able to move before the round starts.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarEngineerPreroundSpeed = CreateConVar("sm_ca_engineer_early_speed", "300.0", "Movement speed (in hammer units) that the engineer has before the round starts.", FCVAR_NOTIFY);

    cvarSunOnAStickDMG = CreateConVar("sm_ca_sun_stick_dmg", "158.0", "Amount of damage to dealt in order to activate fireball.", FCVAR_NOTIFY);
	cvarCrossbowDMG = CreateConVar("sm_ca_crossbow_dmg", "750.0", "Amount of damage to dealt in order to activate explosive arrows.", FCVAR_NOTIFY);
	cvarQuickFixHealingRequired = CreateConVar("sm_ca_quickfix_required_healing", "500.0", "Amount of healing required to activate the personal uber, overheal doesnt count towards it.", FCVAR_NOTIFY);

	AutoExecConfig(true, "custom_abilities");
}

stock void UTIL_AddToDownload()
{
	healingGrenadeModel = PrecacheModel("models/healthvial.mdl");

	beamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	haloSprite = PrecacheModel("materials/sprites/halo01.vmt");

	PrecacheList(MedicAbilityModelList, sizeof(MedicAbilityModelList), true);
	PrecacheList(KnivesModelList, sizeof(KnivesModelList), true);

	PrecacheList(AbilitySoundList, sizeof(AbilitySoundList));
	PrecacheList(MedicPersonalUberSoundList, sizeof(MedicPersonalUberSoundList));
	PrecacheList(MedicGeneralSoundList, sizeof(MedicGeneralSoundList));
	PrecacheList(SniperRandomScreamList, sizeof(SniperRandomScreamList));
	PrecacheList(SpyRandomScreamList, sizeof(SpyRandomScreamList));
	PrecacheList(KnivesSoundList, sizeof(KnivesSoundList));
}

stock void UTIL_ResetPlayerAbilities(int client)
{
	ResetStruct(abilityState[client], sizeof(abilityState)); //HACK: I really dont know why it fills memory with garbage when doing abilityState[client] = {0, ...}
	ResetStruct(projectileState[client], sizeof(projectileState));
	KamikazeEndTime[client] = 0.0;
	DeleteTimer(KamikazeTimer[client]);
	DeleteTimer(GlowTimer);
}

stock void ResetStruct(any[] data, int cells)
{
    for (int i = 0; i < cells; i++)
    {
        data[i] = 0;
    }
}

stock void DeleteTimer(Handle &timer)
{
    if (timer != null)
    {
        delete timer;
        timer = null;
    }
}

static int g_OldButtons[MAXPLAYERS + 1]; // Used for HandleModeSwitch()

stock bool IsValidClient(int client, bool replaycheck = true)
{
	if (client < 1 || client > MaxClients)
		return false;
	
	if (!IsClientInGame(client))
		return false;
	
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;
	
	if (replaycheck)
	{
		if (IsClientSourceTV(client) || IsClientReplay(client))
			return false;
	}
	return true;
}

stock int GetIndexOfWeaponSlot(int client, int slot)
{
	int weapon = GetPlayerWeaponSlot(client, slot);
	return (weapon > MaxClients && IsValidEntity(weapon)) ? GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") : -1;
}

stock bool FindItemInArray(int iItem, int[] iItems, int iItemsLength) {
	for (int idx = 0; idx < iItemsLength; idx++)
	if (iItem == iItems[idx])return true;
	return false;
}

stock bool IsWeaponSlotActive(int client, int slot)
{
	return GetPlayerWeaponSlot(client, slot) == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}

stock void ShowAbilityHud(AbilityHudPos pos, int client, bool ready, const char[] format, any ...)
{
    char buffer[256];
    VFormat(buffer, sizeof(buffer), format, 5);

    Handle hud;
	float y;
	int r = 255;
	int g = ready ? 64 : 255;
	int b = ready ? 64 : 255;

	switch (pos)
	{
		case HUD_TOP:
		{
			hud = TopAbilityHUD;
			y = 0.73;
		}

		case HUD_MIDDLE:
		{
			hud = MiddleAbilityHUD;
			y = 0.78;
		}

		case HUD_BOTTOM:
		{
			hud = BottomAbilityHUD;
			y = 0.83;
		}
	}

	SetHudTextParams(-1.0, y, 0.35, r, g, b, 255);
    ShowSyncHudText(client, hud, buffer);
}
// Stuff i used for testing purposes
stock bool IsAbilityReady(float currentDamage, float requiredDamage)
{
    return currentDamage >= requiredDamage;
}
stock float AbilityPercent(float currentDamage, float requiredDamage)
{
    if (currentDamage >= requiredDamage)
        return 100.0;

    return (currentDamage * 100) / requiredDamage;
}
stock void AbilityCap(float &currentDamage, float requiredDamage)
{
	if (currentDamage > requiredDamage)
		currentDamage = requiredDamage;
}

// A simple way to handle basic Damage Activated Abilities
stock void HandleProgressAbility(int client, AbilityHudPos hudPos, float &currentDamage, float requiredDamage, const char[] readyText, const char[] chargingText, bool &readyFlag)
{
    if (GetClientButtons(client) & IN_SCORE)
        return;

    if (currentDamage > requiredDamage)
        currentDamage = requiredDamage;

    if (currentDamage >= requiredDamage)
    {
        readyFlag = true;
        ShowAbilityHud(hudPos, client, true, readyText);
    }
    else
    {
        readyFlag = false;

        ShowAbilityHud(
            hudPos,
            client,
            false,
            chargingText,
            currentDamage * 100.0 / requiredDamage
        );
    }
}

// Handles cooldowns using GetGameTime(). Sound plays via ClientCommand()
stock void HandleCooldownAbility(int client, AbilityHudPos hudPos, float &storedCooldown, const char[] readyText, const char[] chargingText, bool readySound = false, const char[] soundPath = "")
{
	float timeRemaining = storedCooldown - GetGameTime();

    if (GetClientButtons(client) & IN_SCORE)
        return;

    if (storedCooldown < GetGameTime())
    {
        ShowAbilityHud(hudPos, client, true, readyText);
		if (readySound == true && cooldownSoundPlayed[client] == false)
		{
			if (strlen(soundPath) != 0)
				ClientCommand(client, soundPath);
			else
				ClientCommand(client, "playgamesound items/gunpickup2.wav")
			cooldownSoundPlayed[client] = true;
		}
    }
    else
    {
        ShowAbilityHud(
            hudPos,
            client,
            false,
            chargingText,
            timeRemaining
        );
		cooldownSoundPlayed[client] = false;
    }
}

// A simple way to handle weapons with Switching Modes
stock bool HandleModeSwitch(int client, int &mode, int maxMode, bool allowReload = false)
{
    int buttons = GetClientButtons(client);

    bool pressedM3 =
        !(g_OldButtons[client] & IN_ATTACK3) &&
         (buttons & IN_ATTACK3);

    bool pressedReload =
        allowReload &&
        !(g_OldButtons[client] & IN_RELOAD) &&
         (buttons & IN_RELOAD);

    if (pressedM3 || pressedReload)
    {
        mode++;

        if (mode > maxMode)
            mode = 0;

        EmitSoundToClient(client, "weapons/vaccinator_toggle.wav", _, _, SNDLEVEL_GUNFIRE);

        g_OldButtons[client] = buttons;
        return true;
    }

    g_OldButtons[client] = buttons;
    return false;
}

stock void ThrowSpell(int client, char entityClassname[32])
{
	float fProjectileSpeedMult = 1.0;
	int spell  = CreateEntityByName(entityClassname);

	if(!IsValidEntity(spell))
		return;
	
	float fAng[3], fPos[3];
	GetClientEyeAngles(client, fAng);
	GetClientEyePosition(client, fPos);

	float fVel[3];
	GetAngleVectors(fAng, fVel, NULL_VECTOR, NULL_VECTOR);

	ScaleVector(fVel, 1000.0 * fProjectileSpeedMult);

	int iTeam = view_as<int>(TF2_GetClientTeam(client));

	SetEntPropEnt(spell, Prop_Send, "m_hOwnerEntity", client);
	//SetEntPropEnt(spell, Prop_Send, "m_hLauncher", weapon);
	SetEntProp(spell, Prop_Send, "m_iTeamNum", iTeam, 1);
	SetEntProp(spell, Prop_Send, "m_nSkin", iTeam -2);

	SetVariantInt(iTeam);
	AcceptEntityInput(spell, "TeamNum");
	SetVariantInt(iTeam);
	AcceptEntityInput(spell, "SetTeam");

	DispatchSpawn(spell);

	TeleportEntity(spell, fPos, fAng, fVel);

	return;
}

stock int CreateExplosion(int attacker = -1, int damage = 0, int radius = -1, float pos[3], int flags = 0, const char[] killIcon = "", bool immediate = true, bool explosiveArrow = false)
{
	int explosion = CreateEntityByName("env_explosion");
	
	if (!IsValidEntity(explosion))
		return -1;
	
	char buffer[32];
	
	DispatchKeyValueVector(explosion, "origin", pos);
	
	Format(buffer, sizeof(buffer), "%d", damage);
	DispatchKeyValue(explosion, "iMagnitude", buffer);
	
	// set radius override if specified
	if (radius != -1)
	{
		Format(buffer, sizeof(buffer), "%d", radius);
		DispatchKeyValue(explosion, "iRadiusOverride", buffer);
	}
	
	Format(buffer, sizeof(buffer), "%d", flags);
	DispatchKeyValue(explosion, "spawnflags", buffer);
	
	// set attacker if specified
	if (attacker != -1)
		SetEntPropEnt(explosion, Prop_Data, "m_hOwnerEntity", attacker);
	
	DispatchSpawn(explosion);
	
	// change the kill icon if specified
	if (killIcon[0])
	{
		Format(buffer, sizeof(buffer), "classname %s", killIcon);
		SetVariantString(buffer);
		AcceptEntityInput(explosion, "AddOutput");
	}
	
	// do the explosion and clean up right here if it's set to do immediately, or let the explosion be manipulated further if not
	if (immediate)
	{
		AcceptEntityInput(explosion, "Explode");
		CreateTimer(0.1, Timer_RemoveEntity, EntIndexToEntRef(explosion), TIMER_FLAG_NO_MAPCHANGE);
	}

	if (explosiveArrow == true)
	{
		AcceptEntityInput(explosion, "Explode");
		TeleportEntity(explosion, pos, NULL_VECTOR, NULL_VECTOR);
		CreateTimer(0.1, Timer_RemoveEntity, EntIndexToEntRef(explosion), TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return explosion;
}

public Action Timer_RemoveEntity(Handle timer, any entid)
{
	int entity = EntRefToEntIndex(entid);
	if(IsValidEdict(entity) && entity>MaxClients)
	{
		TeleportEntity(entity, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR); // send it away first in case it feels like dying dramatically
		RemoveEntity(entity);
	}
	return Plugin_Continue;
}

stock void PrecacheList(char[][] szFileList, int iSize, bool isModel = false)
{
	for (int i = 0; i < iSize; i++)
	{
		if (isModel)
			PrecacheModel(szFileList[i], true);
		else
			PrecacheSound(szFileList[i], true);
	}
}

stock void PlayRandomSound(int client, char[][] soundList, int soundCount)
{
    EmitSoundToClient(client, soundList[GetRandomInt(0, soundCount - 1)]);
}

stock void PlayRandomSoundToAll(char[][] soundList, int soundCount)
{
    EmitSoundToAll(soundList[GetRandomInt(0, soundCount - 1)]);
}

stock int GetAmmoClipNum(int weapon)
{
	return GetEntProp(weapon, Prop_Send, "m_iClip1");
}

stock int GetAmmoNum(int client, int weapon)
{
	return GetEntData(client, FindSendPropInfo("CTFPlayer", "m_iAmmo") + GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1) * 4, 4);
}

stock void SetAmmo(int client, int iWeapon, int iAmmo = 50)
{
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if(iAmmoType != -1) SetEntProp(client, Prop_Data, "m_iAmmo", iAmmo, _, iAmmoType);
}

stock void SetClip(int iWeapon, int iClip = 99)
{
	SetEntProp(iWeapon, Prop_Data, "m_iClip1", iClip);
}

stock ArrayList DetectEnemiesNearby(int client, float origin[3], float radius, bool includeSelf = false)
{
    ArrayList targets = new ArrayList();

    for (int target = 1; target <= MaxClients; target++)
    {
        if (!IsValidClient(target) || !IsPlayerAlive(target))
            continue;

        if (!includeSelf && target == client)
            continue;

        float targetPos[3];
        GetClientAbsOrigin(target, targetPos);

        if (GetVectorDistance(origin, targetPos) <= radius)
        {
            targets.Push(target);
        }
    }

    return targets;
}

stock bool SpawnTempEntity(const char[] classname, float origin[3], const char[] input = "", bool removeAfter = true)
{
    int entity = CreateEntityByName(classname);

    if (!IsValidEntity(entity))
    {
        LogError("Failed to create entity '%s'.", classname);
        return false;
    }

    DispatchSpawn(entity);
    TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);

    if (strlen(input) > 0)
        AcceptEntityInput(entity, input);

    if (removeAfter)
        RemoveEdict(entity);

    return true;
}

stock void DoDamage(int client, int target, int amount)
{
	int pointHurt = CreateEntityByName("point_hurt");
	if (pointHurt)
	{
		DispatchKeyValue(target, "targetname", "explodeme");
		DispatchKeyValue(pointHurt, "DamageTarget", "explodeme");
		char dmg[15];
		Format(dmg, 15, "%i", amount);
		DispatchKeyValue(pointHurt, "Damage", dmg);
		DispatchKeyValue(pointHurt, "DamageType", "0");

		DispatchSpawn(pointHurt);
		AcceptEntityInput(pointHurt, "Hurt", client);
		DispatchKeyValue(pointHurt, "classname", "point_hurt");
		DispatchKeyValue(target, "targetname", "");
		RemoveEdict(pointHurt);
	}
}

void SetParentSimple(int iParent, int iChild)
{
	SetVariantString("!activator");
	AcceptEntityInput(iChild, "SetParent1", iParent, iChild);
}

stock int AttachParticle(int iEnt, const char[] szParticleType, float flTimeToDie = -1.0, float vOffsets[3] = {0.0,0.0,0.0}, float rOffsets[3] = {0.0,0.0,0.0}, bool bAttach = false, float flTimeToStart = -1.0)
{
	int iParti = CreateEntityByName("info_particle_system");
	if (IsValidEntity(iParti))
	{
		float vPos[3],rPos[3];
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);
		AddVectors(vPos, vOffsets, vPos);
		AddVectors(rPos, rOffsets, rPos);
		TeleportEntity(iParti, vPos, rPos, NULL_VECTOR);

		DispatchKeyValue(iParti, "effect_name", szParticleType);
		DispatchSpawn(iParti);

		if (bAttach)
		{
			SetParentSimple(iEnt, iParti);
			SetEntPropEnt(iParti, Prop_Send, "m_hOwnerEntity", iEnt);
		}

		ActivateEntity(iParti);

		if (flTimeToStart > 0.0)
		{
			char szAddOutput[32];
			Format(szAddOutput, sizeof(szAddOutput), "OnUser1 !self,Start,,%0.2f,1", flTimeToStart);
			SetVariantString(szAddOutput);
			AcceptEntityInput(iParti, "AddOutput");
			AcceptEntityInput(iParti, "FireUser1");

			if (flTimeToDie > 0.0)
			{
				flTimeToDie += flTimeToStart;
			}
		}
		else
		{
			AcceptEntityInput(iParti, "Start");
		}

		if (flTimeToDie > 0.0) 
		{
			killEntityIn(iParti, flTimeToDie);
		}

		return iParti;
	}
	return -1;
}

void killEntityIn(int iEnt, float flSeconds)
{
	char szAddOutput[32];
	Format(szAddOutput, sizeof(szAddOutput), "OnUser1 !self,Kill,,%0.2f,1", flSeconds);
	SetVariantString(szAddOutput);
	AcceptEntityInput(iEnt, "AddOutput");
	AcceptEntityInput(iEnt, "FireUser1");
}

stock bool TraceEntityFilterPlayer(int entity, int contentsMask) //Borrowed from Apocalips
{
	return entity > MaxClients;
}

stock float DistanceAboveGround(int client)
{
	float vStart[3];
	float vEnd[3];
	float vAngles[3] = {90.0, 0.0, 0.0};
	float distance = -1.0;
	Handle trace;

	GetClientAbsOrigin(client, vStart);
	trace = TR_TraceRayFilterEx(vStart, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);

	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(vEnd, trace);
		distance = GetVectorDistance(vStart, vEnd, false);
	} else
	{
		LogError("Trace error: client %N (%d)", client, client);
	}

	CloseHandle(trace);
	return distance;
}

stock int TF2_AttachColoredGlow(int entity, TFTeam team = TFTeam_Unassigned, int rgba[4] = {255,255,255,255})
{
	int glow = CreateEntityByName("tf_glow");
	
	if (IsValidEntity(glow))
	{
		char glowTarget[PLATFORM_MAX_PATH]; // Stores the original name.
		GetEntPropString(entity, Prop_Data, "m_iName", glowTarget, sizeof(glowTarget))
		char tempName[32];
		Format(tempName, sizeof(tempName), "glow_%d", EntIndexToEntRef(entity));

		SetEntPropString(entity, Prop_Data, "m_iName", tempName); // Applies temp name
		DispatchKeyValue(glow, "target", tempName);
		
		DispatchSpawn(glow);

		switch(team)
		{
			case TFTeam_Red:
			{
				rgba = {184, 56, 59, 255};
			}
			case TFTeam_Blue:
			{
				rgba = {88, 133, 162, 255}
			}
		}
		
		SetVariantColor(rgba);
		AcceptEntityInput(glow, "SetGlowColor");

		SetEntPropString(entity, Prop_Data, "m_iName", glowTarget); // Restores the original name.
	}
	return glow;
}

stock bool TF2_RemoveGlow(int iEnt)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt)
		{
			RemoveEntity(index);
			return true;
		}
	}
	return false;
}

stock bool IsValidClientIndex(int client)
{
    return (client >= 1 && client <= MaxClients && IsClientInGame(client));
}

stock void SetViewmodelAnimation(int client, const char[] activity) {
    char buffer[PLATFORM_MAX_PATH];
    Format(buffer, sizeof(buffer), "self.ResetSequence(self.LookupSequence(`%s`))", activity);
    SetVariantString(buffer);
    AcceptEntityInput(GetEntPropEnt(client, Prop_Send, "m_hViewModel"), "RunScriptCode");
} 

// Hopefully this fixes the pomson causing multiple damage ticks when having penetration enabled.
stock bool ShouldBlockProjectileMultiHit(int projectile, int victim)
{
    int tick = GetGameTickCount();

    if (projectileState[projectile].lastVictim == victim && (tick - projectileState[projectile].lastTick) <= 10)
    {
        return true;
    }

    projectileState[projectile].lastVictim = victim;
    projectileState[projectile].lastTick = tick;

    return false;
}

stock void ClientSwitchWeaponSlot(int client, int slot)
{
    for (int i = 0; i < 3; i++) // Primary, Secondary, Melee
    {
        int currentSlot = (slot + i) % 3;
        int weapon = GetPlayerWeaponSlot(client, currentSlot);

        if (IsValidEntity(weapon))
        {
            EquipPlayerWeapon(client, weapon);
            return;
        }
    }
}

public void PushClient(int client)
{
    float fVelocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
    fVelocity[0] = fVelocity[0]-fVelocity[0]-fVelocity[0];
    if (fVelocity[0] == 0.0) fVelocity[0] = (GetRandomInt(0,1)==1)?-100.0:100.0;
    fVelocity[1] = fVelocity[1]-fVelocity[1]-fVelocity[1];
    if (fVelocity[1] == 0.0) fVelocity[1] = (GetRandomInt(0,1)==1)?-100.0:100.0;
    fVelocity[2] = 400.0;

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVelocity);
}

// Hello there! :D
// If you like this plugin, please leave this little advertisement intact. ❤️
// I even avoided using MoreColors to keep compilation as simple as possible. T-T
stock void AdvertisePlugin()
{
    PrintToChatAll("\x01[\x04Abilities\x01] Running \x03Custom Abilities v%s\x01 by \x05Latte\x01.", PLUGIN_VERSION);
    PrintToChatAll("\x01[\x04Abilities\x01] This server features unique weapon abilities. Press \x03M3\x01 or \x03Reload\x01 if your weapon indicates it!");
}