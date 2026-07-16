public void OnPluginStart()
{
	CreateTimer(0.2, LogicTimer, _, TIMER_REPEAT);
	CreateTimer(900.0, Timer_Advertise, _, TIMER_REPEAT);

	UTIL_MakeConVars();
	UTIL_MakeHUDS();
	UTIL_MakeGameEventHooks();
	UTIL_HookExistingClients(); // Hooks when using plugin reload
}

public void OnMapStart()
{
	for (int client = 1; client <= MaxClients; client++)
	{
    	UTIL_ResetPlayerAbilities(client);
	}

	UTIL_AddToDownload();
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	SDKHook(client, SDKHook_WeaponCanSwitchTo, OnWeaponCanSwitchTo);
	UTIL_ResetPlayerAbilities(client);
}

public void OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	SDKUnhook(client, SDKHook_WeaponCanSwitchTo, OnWeaponCanSwitchTo);
	UTIL_ResetPlayerAbilities(client);
}

public void EventRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (cvarShouldEngineerMoveOnPreround.BoolValue)
	{
		CreateTimer(0.1, Timer_GiveEngineersSpeed, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action EventPlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
		
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	UTIL_ResetPlayerAbilities(client);

	return Plugin_Continue;
}

public Action EventInventoryApplicationPost(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	int primaryWeaponIndex = GetIndexOfWeaponSlot(client, TFWeaponSlot_Primary);
	int secondaryWeaponIndex = GetIndexOfWeaponSlot(client, TFWeaponSlot_Secondary);

	if (!IsValidClient(client) || !IsPlayerAlive(client))
        return Plugin_Continue;
    #if defined VSH
    if (TF2_GetClientTeam(client) != TFTeam_Red)
        return Plugin_Continue;
    #endif

	if (cvarDiamondBackAbility.BoolValue && primaryWeaponIndex == 525) // Diamondback
	{
		int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);

		TF2Attrib_RemoveAll(weapon);
		TF2Attrib_SetByName(weapon, "override projectile type", 2.0);

		if (cvarDiamondbackEnhancedJump.BoolValue)
		{
			TF2Attrib_SetByName(weapon, "mod_air_control_blast_jump", 2.0);
			TF2Attrib_SetByName(weapon, "self dmg push force increased", 1.5);
		}
		if (!cvarDiamondbackAllowAmmoPickup.BoolValue)
		{
			TF2Attrib_SetByName(weapon, "hidden secondary max ammo penalty", 0.0);
			//TF2Attrib_SetByName(weapon, "maxammo secondary reduced", 0.0); // Doesnt work unless the client touches a resupply.
			SetAmmo(client, weapon, 0); // Should work since the attrib doesnt.
		}

		SetClip(weapon, cvarDiamondbackStartingClip.IntValue); // Starting limit so the spy has to actually think about managing his rockets.
	}

	if (cvarFamilyBusinessIsFatScout.BoolValue && secondaryWeaponIndex == 425) // Family Business
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
		ClientSwitchWeaponSlot(client, TFWeaponSlot_Secondary);

		int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);
		TF2Attrib_SetByName(weapon, "major move speed bonus", cvarFatScoutSpeedBuff.FloatValue);
	}

	if (primaryWeaponIndex == 588) // Pomson
	{
		int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
		if (cvarPomsonHasPenetration.BoolValue)
			TF2Attrib_SetByName(weapon, "energy weapon penetration", 1.0);
	}
	return Plugin_Continue;
}

public Action OnWeaponCanSwitchTo(int client, int weapon)
{
    return Knives_OnWeaponCanSwitchTo(client, weapon);
}

public Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
    if (!IsValidClient(attacker) || !IsPlayerAlive(attacker) || !IsValidClient(victim) || attacker == victim || !IsValidEntity(inflictor))
        return Plugin_Continue;
    #if defined VSH
    if (TF2_GetClientTeam(attacker) != TFTeam_Red)
        return Plugin_Continue;
    #endif

    int	index;
    static char classname[64];

    if (IsValidEntity(weapon) && weapon > MaxClients && attacker <= MaxClients)
	{
		GetEntityClassname(weapon, classname, sizeof(classname));
		if (!HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))	 // Dang spell Monoculuses
		{
			index = -1;
			classname[0] = 0;
		}
		else
		{
			index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		}
	}
	else
	{
		index = -1;
		classname[0] = 0;
	}
    switch (index)
    {
        case 44: // Sandman
        {
            if (!cvarShouldSandmanStun.BoolValue)
                return Plugin_Continue;
            float fClientLocation[3];
			float fClientEyePosition[3];
			GetClientAbsOrigin(attacker, fClientEyePosition);
			GetClientAbsOrigin(victim, fClientLocation);
			float fDistance[3];
			MakeVectorFromPoints(fClientLocation, fClientEyePosition, fDistance);
			float dist = GetVectorLength(fDistance);
			if (dist >= 450.0 && dist < 768.0) {
			TF2_StunPlayer(victim, 3.0, 0.0, TF_STUNFLAGS_SMALLBONK, attacker);
			}
			else if (dist >= 768.0 && dist < 1024.0) {
				TF2_StunPlayer(victim, 4.0, 0.0, TF_STUNFLAGS_SMALLBONK, attacker);
			}
			else if (dist >= 1024.0 && dist < 1280.0) {
				TF2_StunPlayer(victim, 5.0, 0.0, TF_STUNFLAGS_SMALLBONK, attacker);
			}
			else if (dist >= 1280.0 && dist < 1536.0) {
			TF2_StunPlayer(victim, 6.0, 0.0, TF_STUNFLAGS_SMALLBONK, attacker);
			}
			else if (dist >= 1536.0 && dist < 1792.0) {
			TF2_StunPlayer(victim, 7.0, 0.0, TF_STUNFLAGS_SMALLBONK, attacker);
			}
			else if (dist >= 1792.0) {
			TF2_StunPlayer(victim, 7.0, 0.0, TF_STUNFLAGS_BIGBONK, attacker);
			}
        }
		case 349: // Sun-on-a-Stick
		{
			if (cvarSunOnAStickAbility.BoolValue && damagetype != TF_CUSTOM_SPELL_FIREBALL)
			{
				abilityState[attacker].meleeProgress += RoundToCeil(damage);
			}
		}
		case 1151: // Iron Bomber
		{
			if (cvarIronBomberHasHitStreak.BoolValue)
			{
				if (cvarIronBomberStacksWithSplash.BoolValue)
				{
					HandleHitStreak(abilityState[attacker].weaponHitStreak, abilityState[attacker].weaponLastHitTime, cvarIronBomberHitStreakTimeout.FloatValue, cvarIronBomberMaxStacks.IntValue, cvarIronBomberDamagePerStack.FloatValue, true, damage);
					return Plugin_Changed;
				}
				else // Hit detection is being handled using SDKHook_StartTouch
				{
					float multiplier = 1.0 + (abilityState[attacker].weaponHitStreak * cvarIronBomberDamagePerStack.FloatValue);
					damage *= multiplier;
					return Plugin_Changed;
				}
			}
		}
		case 425: // Family Business
		{
			int maxHealth = GetEntProp(attacker, Prop_Data, "m_iMaxHealth");
			int maxAllowedHealth = maxHealth + cvarFatScoutOverheal.IntValue;

			int health = GetClientHealth(attacker);

			if (health < maxAllowedHealth)
			{
				int healAmount = RoundToCeil(damage);

				if (healAmount > cvarFatScoutLifesteal.IntValue)
					healAmount = cvarFatScoutLifesteal.IntValue;

				int newHealth = health + healAmount;

				if (newHealth > maxAllowedHealth)
					newHealth = maxAllowedHealth;

				SetEntityHealth(attacker, newHealth);
			}
		}
		case 588: // Pomson
		{
			if (cvarPomsonHasKnockback.BoolValue)
			{
				if (ShouldBlockProjectileMultiHit(inflictor, victim))
				{
					damage = 0.0;
				}
				else
				{
					if (cvarPomsonHasAirshotStreak.BoolValue && cvarHuntsmanAbility.BoolValue && DistanceAboveGround(victim) >= cvarHuntsmanMinHeightForAirshot.FloatValue)
					{
						HandleHitStreak(abilityState[attacker].weaponHitStreak, abilityState[attacker].weaponLastHitTime, 1.5, 5, cvarPomsonDamagePerStack.FloatValue, true, damage);
					}
					return Plugin_Changed;
				}
				float fVelocity[3];
				GetEntPropVector(victim, Prop_Data, "m_vecVelocity", fVelocity);
				fVelocity[0] = cvarPomsonKnockbackHorizontal.FloatValue;
				fVelocity[2] = cvarPomsonKnockbackVertical.FloatValue;

				TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, fVelocity);
				return Plugin_Changed;
			}
		}
		case 305, 1079: // Crossbows
		{
			if (cvarCrossbowAbility.BoolValue)
			{
				abilityState[attacker].primaryProgress += RoundToCeil(damage);
			}
		}
		case 56, 1005, 1092: // Huntsman
		{
			if (cvarHuntsmanAbility.BoolValue && DistanceAboveGround(victim) >= cvarHuntsmanMinHeightForAirshot.FloatValue)
			{
				PlayRandomSoundToAll(SniperRandomScreamList, sizeof(SniperRandomScreamList));
				damage *= cvarHuntsmanAirshotDamageMultiplier.FloatValue;
				return Plugin_Changed;
			}
		}
    }
	if (damagecustom == TF_CUSTOM_BACKSTAB && GetIndexOfWeaponSlot(attacker, TFWeaponSlot_Primary) == 525) // If was a backstab and has Diamondback
	{
		if (cvarDiamondbackAllowAmmoPickup.BoolValue) // Only give ammo if the user cant pick up ammo packs.
			return Plugin_Continue;
		int currentAmmo = GetAmmoNum(attacker, GetPlayerWeaponSlot(attacker, 0));
		SetAmmo(attacker, GetPlayerWeaponSlot(attacker, 0), currentAmmo + cvarDiamondbackAmmoToGive.IntValue);
	}

	GetEdictClassname(inflictor, classname, sizeof(classname));
	if (StrEqual(classname, "obj_sentrygun"))
	{
		bool isMini = GetEntProp(inflictor, Prop_Send, "m_bMiniBuilding") != 0;
		int glowType = cvarSentryGlowType.IntValue;

		if (isMini && !(glowType & Glow_Mini))
			return Plugin_Continue;

		if (!isMini && !(glowType & Glow_Sentry))
			return Plugin_Continue;
		
		if (!abilityState[victim].hasGlowApplied)
			{
			abilityState[victim].glowDuration += cvarSentryGlowTimeToAdd.FloatValue; // Somehow I always find a way to bug it using GetGameTime() so I CBA.
			abilityState[victim].glowEntRef = TF2_AttachColoredGlow(victim, TF2_GetClientTeam(victim));
			abilityState[victim].hasGlowApplied = true;
			if (GlowTimer == null)
			{
				GlowTimer = CreateTimer(0.2, Timer_GlowCheck, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		else
		{
			if (abilityState[victim].glowDuration >= cvarSentryMaxGlowTime.FloatValue)
				abilityState[victim].glowDuration = cvarSentryMaxGlowTime.FloatValue;
			else
				abilityState[victim].glowDuration += cvarSentryGlowTimeToAdd.FloatValue;
		}
	}
    return Plugin_Continue;
}

public Action EventPlayerHealed(Handle event, const char[] name, bool dontBroadcast)
{
	// This works fine as i dont intend to count overheal.
	// If you need it, GetEntProp(entity, Prop_Send, "m_bHealing") might be a good starting point.
	int patient = GetClientOfUserId(GetEventInt(event, "patient"));
	int healer = GetClientOfUserId(GetEventInt(event, "healer"));
	float healAmount = GetEventFloat(event, "amount");

	if (patient != healer)
	{
		abilityState[healer].healingDone += healAmount;
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsValidClient(client) || !IsPlayerAlive(client))
            return Plugin_Continue;
    #if defined VSH
    if (TF2_GetClientTeam(client) != TFTeam_Red)
        	return Plugin_Continue;
    #endif

	int	index;
	int currentWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"); // &weapon: Entity index of the new weapon if player switches weapon, 0 otherwise.
	
	if (!IsValidEntity(currentWeapon) || !HasEntProp(currentWeapon, Prop_Send, "m_iItemDefinitionIndex"))
		return Plugin_Continue;
	
	index = GetEntProp(currentWeapon, Prop_Send, "m_iItemDefinitionIndex");
	switch (index)
	{
		case 349: //Sun-on-a-Stick
		{
			if (buttons & IN_ATTACK3 && abilityState[client].meleeAvailable == true)
			{
				ThrowSpell(client, "tf_projectile_spellfireball");
				abilityState[client].meleeAvailable = false;
				abilityState[client].meleeProgress = 0.0;
			}
		}
		case 19, 206, 1007: // Grenade Launcher | Default, Strange, Festive
		{
			if (cvarGrenadeLauncherHasModes.BoolValue && HandleModeSwitch(client, grenadeLauncherMode[client], GrenadeLauncher_Charge, false)) // Changing modes with Reload would be annoying to some, so beware.
			{
				GrenadeLauncher_ChangeMode(currentWeapon, grenadeLauncherMode[client])
			}
		}
		case 29, 796, 805, 885, 894, 903, 912, 961, 970: // Medigun
		{
			if (cvarMedigunAbility.BoolValue && abilityState[client].secondaryCooldown < GetGameTime() && buttons & IN_ATTACK3)
			{
				abilityState[client].secondaryCooldown = GetGameTime() + cvarHealingGrenadeCooldown.FloatValue;
				ThrowTemporaryHealingGrenade(client)
			}
		}
		case 411: // The Quick-Fix
		{
			if(cvarQuickFixAbility.BoolValue && abilityState[client].secondaryAvailable && buttons & IN_ATTACK3)
			{
				TF2_AddCondition(client, TFCond_UberchargedCanteen, 3.0);
				PlayRandomSoundToAll(MedicPersonalUberSoundList, sizeof(MedicPersonalUberSoundList));
				abilityState[client].secondaryAvailable = false;
				abilityState[client].healingDone = 0.0;
			}
		}
		case 998: // The Vaccinator
		{
			if (cvarVaccinatorAbility.BoolValue && abilityState[client].secondaryCooldown < GetGameTime() && buttons & IN_ATTACK3)
			{
				abilityState[client].secondaryCooldown = GetGameTime() + cvarMedicShieldCooldown.FloatValue;
				CreateMedicShield(client);
			}
		}
		case 735, 736, 831, 933, 1080, 1102: // Sappers excluding Red-Tape
		{
			if (cvarSapperKamikazeAbility.BoolValue && KamikazeTimer[client] == null && buttons & IN_ATTACK3)
			{
				if(!TF2_IsPlayerInCondition(client, TFCond_Cloaked) && !TF2_IsPlayerInCondition(client, TFCond_Disguised) && !TF2_IsPlayerInCondition(client, TFCond_Disguising))
				{
					StartKamikaze(client);
				}
			}
		}
		case 225, 356, 461, 649, 4, 194, 665, 727, 794, 803, 883, 892, 901, 910, 959, 968, 15062, 15094, 15095, 15096, 15118, 15119, 15143, 15144: // All Knives
		{
			if (cvarKnifeThrowAbility.BoolValue && abilityState[client].meleeCooldown < GetGameTime() && buttons & IN_ATTACK3)
			{
				if(!TF2_IsPlayerInCondition(client, TFCond_Cloaked))
				{
					abilityState[client].meleeCooldown = GetGameTime() + cvarKnifeThrowAbilityCooldown.FloatValue;
					CreateThrownKnife(client);
				}
			}
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_projectile_healing_bolt"))
	{
		SDKHook(entity, SDKHook_StartTouch, OnArrowStartTouch);
	}
	if (StrEqual(classname, "tf_projectile_pipe"))
	{
		SDKHook(entity, SDKHook_StartTouch, OnPipeStartTouch);
	}
	// if (StrEqual(classname, "tf_projectile_arrow"))
	// {
	// 	RequestFrame(arrowNextFrame, entity);
	// }
}

public void OnArrowStartTouch(int entity, int other)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	bool validOwner = IsValidClientIndex(owner);

	if (other == owner)
		return;
	
	if (validOwner && abilityState[owner].hasExplosiveArrows)
    {
        float origin[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);

        CreateExplosion(owner, 50, 200, origin, 2);
    }
}
public void OnPipeStartTouch(int entity, int other)
{
	int thrower = GetEntPropEnt(entity, Prop_Send, "m_hThrower");

	bool validThrower = IsValidClientIndex(thrower);

	if (other == thrower)
        return;

	bool hitPlayer = IsValidClientIndex(other);

	if (hitPlayer && validThrower)
	{
		HandleHitStreak(abilityState[thrower].weaponHitStreak, abilityState[thrower].weaponLastHitTime, cvarIronBomberHitStreakTimeout.FloatValue, cvarIronBomberMaxStacks.IntValue, cvarIronBomberDamagePerStack.FloatValue, false);
	} //TODO: Add terrain detection and a cvar to see if we should restart the streak instead of doing it by LastHitTime.
}