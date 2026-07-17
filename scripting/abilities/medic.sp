/*
    INCLUDED: UTILS.SP
    USE LOCATIONS:
        * ThrowTemporaryHealingGrenade(int client) => Events.sp | OnPlayerRunCmd
*/
// TOGGLES
ConVar cvarCrossbowAbility;
ConVar cvarMedigunAbility;
ConVar cvarQuickFixAbility;
ConVar cvarVaccinatorAbility;

// REQUIREMENTS
ConVar cvarCrossbowDMG;
ConVar cvarQuickFixHealingRequired;

// SPECIFIC CONVARS
ConVar cvarHealingGrenadeDuration;
ConVar cvarHealingGrenadeHealDelay;
ConVar cvarHealingGrenadeHealAmount;
ConVar cvarHealingGrenadeOverhealAmount;
ConVar cvarHealingGrenadeCooldown;

ConVar cvarMedicShieldCooldown;
ConVar cvarMedicShieldShouldPush;

static float healDelay[MAXENTITIES];
static float healDuration[MAXENTITIES];
int healingGrenadeModel;

char MedicPersonalUberSoundList[][] =
{
    "vo/medic_weapon_taunts01.mp3",
    "vo/medic_weapon_taunts02.mp3",
    "vo/medic_autodejectedtie01.mp3",
    "vo/medic_autochargeready03.mp3",
};

char MedicGeneralSoundList[][] =
{
    "weapons/medi_shield_deploy.wav",
}

char MedicAbilityModelList[][] =
{
    "models/props_mvm/mvm_player_shield2.mdl",
}

public void ThrowTemporaryHealingGrenade(int client)
{
    int entity = CreateEntityByName("tf_projectile_pipe");
    if (!IsValidEntity(entity))
    {
        LogError("There was an error trying to create tf_projectile_pipe");
        return;
    }
    static float pos[3], ang[3], vel[3];
    GetClientEyeAngles(client, ang);
    GetClientEyePosition(client, pos);

    ang[0] -= 8.0;

    float speed = 1500.0;

    vel[0] = Cosine(DegToRad(ang[0]))*Cosine(DegToRad(ang[1]))*speed;
	vel[1] = Cosine(DegToRad(ang[0]))*Sine(DegToRad(ang[1]))*speed;
	vel[2] = Sine(DegToRad(ang[0]))*speed;
	vel[2] *= -1;

    int team = TF2_GetClientTeam(client);

    SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	SetEntProp(entity, Prop_Send, "m_iTeamNum", team, 1);
    SetEntProp(entity, Prop_Send, "m_nSkin", (team-2)); 
    SetEntPropEnt(entity, Prop_Send, "m_hThrower", client);
    SetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher", 0);

    for(int i; i < 4; i++)
	{
		SetEntProp(entity, Prop_Send, "m_nModelIndexOverrides", healingGrenadeModel, _, i);
	}

    DispatchSpawn(entity);
    TeleportEntity(entity, pos, ang, vel);
    
    int healingAmount = cvarHealingGrenadeHealAmount.IntValue;
    healDelay[entity] = GetGameTime() + cvarHealingGrenadeHealDelay.FloatValue;
    healDuration[entity] = GetGameTime() + cvarHealingGrenadeDuration.FloatValue;

    SetEntProp(entity, Prop_Data, "m_nNextThinkTick", -1);

    DataPack pack;
    CreateDataTimer(0.1, Timer_DetectPlayerNearHealingGrenade, pack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
    pack.WriteCell(EntIndexToEntRef(entity));
	pack.WriteCell(healingAmount);	
	pack.WriteCell(GetClientUserId(client));
}

public Action Timer_DetectPlayerNearHealingGrenade(Handle timer, DataPack pack)
{
    pack.Reset();
    int entity = EntRefToEntIndex(pack.ReadCell());
	int healingAmount = pack.ReadCell();
	int client = GetClientOfUserId(pack.ReadCell());

    if (entity < MaxClients || healDuration[entity] < GetGameTime() || !IsValidClient(client))
    {
        if (entity != -1)
            RemoveEntity(entity);
        return Plugin_Stop;
    }

    float grenadePos[3];
    float healingTargetPos[3];
    GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", grenadePos);
    
    if (healDelay[entity] < GetGameTime())
    {
        healDelay[entity] = GetGameTime() + 1.0;
        int color[4] = {0, 255, 0, 255};

        TE_SetupBeamRingPoint(grenadePos, 10.0, 500.0 * 2.0, beamSprite, -1, 0, 5, 0.5, 5.0, 1.0, color, 0, 0);
        TE_SendToAll();

        for (int target = 1; target <= MaxClients; target++)
        {
            if (IsValidClient(target) && IsPlayerAlive(target) && TF2_GetClientTeam(target) == TF2_GetClientTeam(client))
            {
                GetClientAbsOrigin(target, healingTargetPos);
                if (GetVectorDistance(grenadePos, healingTargetPos, true) <= (500.0 * 500.0))
                {
                    EmitSoundToClient(target, "items/medshot4.wav", target, _, 90, _, 1.0);
                    int lastHealth = GetClientHealth(target);
                    int newHealth = lastHealth; // Useful if later I want to add modifiers, so im leaving it
                    int maxHealth = GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, target);
                    int grenadeMaxHealth = maxHealth + cvarHealingGrenadeOverhealAmount.IntValue;

                    if (newHealth >= grenadeMaxHealth)
                        continue;

                    newHealth += healingAmount;

                    if (newHealth > grenadeMaxHealth)
                        newHealth = grenadeMaxHealth;

                    SetEntityHealth(target, newHealth);
                }
            }
        }
    }
    return Plugin_Continue;
}

stock int CreateMedicShield(int owner, int rotate = 0)
{
	int shield = CreateEntityByName("entity_medigun_shield");
	if(shield != -1) {
		SetEntPropEnt(shield, Prop_Send, "m_hOwnerEntity", owner);    
		SetEntProp(shield, Prop_Send, "m_iTeamNum", GetClientTeam(owner));    
		SetEntProp(shield, Prop_Data, "m_iInitialTeamNum", GetClientTeam(owner));    
		
		char RotateStr[30];
		FormatEx(RotateStr, 30, "%i 0 0", rotate);
		DispatchKeyValue(shield, "angles", RotateStr);
		
		if (GetClientTeam(owner) == view_as<int>(TFTeam_Red)) DispatchKeyValue(shield, "skin", "0");
		else if (GetClientTeam(owner) == view_as<int>(TFTeam_Blue)) DispatchKeyValue(shield, "skin", "1");
		SetEntPropFloat(owner, Prop_Send, "m_flRageMeter", 100.0);
		SetEntProp(owner, Prop_Send, "m_bRageDraining", 1);
		DispatchSpawn(shield);
		char s[PLATFORM_MAX_PATH];
		Format(s, PLATFORM_MAX_PATH, "weapons/medi_shield_deploy.wav");
		float pos[3];
		pos[2] += 20.0;
		EmitSoundToAll(s, owner, SNDCHAN_VOICE, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, owner, pos, NULL_VECTOR, true, 0.0);
		SetEntityModel(shield, "models/props_mvm/mvm_player_shield2.mdl");
		SDKHook(shield, SDKHook_StartTouch, OnShieldStartTouch);
		return true;
	} else return false;
}

public void OnShieldStartTouch(int entity, int other)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

	bool validOwner = IsValidClientIndex(owner);

	if (other == owner)
        return;

	bool hitPlayer = IsValidClientIndex(other);

	if (hitPlayer && validOwner && cvarMedicShieldShouldPush.BoolValue)
	{
        PushClient(other);
    }
}

Action Shield_OnWeaponCanSwitchTo(int client, int weapon)
{
    if (GetGameTime() >= abilityState[client].lockUntil)
        return Plugin_Continue;

    if (weapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Melee) || weapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Primary))
        return Plugin_Handled;

    return Plugin_Continue;
}