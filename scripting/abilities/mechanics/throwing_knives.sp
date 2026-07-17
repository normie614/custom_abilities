enum struct ThrownKnife
{
    int owner;
    int weaponDefIndex;
    int projectileRef;
    Handle returnTimer;
    bool hitPlayer;
}
ThrownKnife knifeState[MAXENTITIES];

enum KnifeEffect
{
	KnifeEffect_None,
	KnifeEffect_DeepWound,
	KnifeEffect_Heal,
	KnifeEffect_Speed,
	KnifeEffect_Cloak,
	KnifeEffect_Freeze
}

char KnivesModelList[][] =
{
    "models/weapons/c_models/c_knife/c_knife.mdl",
    "models/weapons/c_models/c_switchblade/c_switchblade.mdl",
    "models/weapons/c_models/c_shogun_kunai/c_shogun_kunai.mdl",
    "models/weapons/c_models/c_eternal_reward/c_eternal_reward.mdl",
    "models/weapons/c_models/c_xms_cold_shoulder/c_xms_cold_shoulder.mdl"
}
char KnivesSoundList[][] =
{
    "misc/halloween/strongman_fast_whoosh_01.wav",
    "weapons/cleaver_throw.wav",
    "weapons/cleaver_hit_world.wav",
    "weapons/cleaver_hit_02.wav"
}

stock KnifeEffect GetKnifeEffect(int defIndex)
{
	switch (defIndex)
	{
		case 4, 194, 665, 727, 794, 803, 883, 892, 901, 910, 959, 968, 15062, 15094, 15095, 15096, 15118, 15119, 15143, 15144:
        return KnifeEffect_DeepWound;   // Default knife / Black Rose
		case 356: return KnifeEffect_Heal; // Conniver's Kunai
		case 461: return KnifeEffect_Speed; // The Big Earner
		case 225, 574: return KnifeEffect_Cloak; // Your Eternal Reward / The Wanga Prick
		case 649: return KnifeEffect_Freeze; // The Spy-cicle
	}

	return KnifeEffect_None; // fallback default
}

stock void GetKnifeModel(int defIndex, char[] buffer, int maxlength)
{
	switch (defIndex)
	{
		case 356: strcopy(buffer, maxlength, "models/weapons/c_models/c_shogun_kunai/c_shogun_kunai.mdl");
		case 461: strcopy(buffer, maxlength, "models/weapons/c_models/c_switchblade/c_switchblade.mdl");
		case 225, 574: strcopy(buffer, maxlength, "models/weapons/c_models/c_eternal_reward/c_eternal_reward.mdl");
		case 649: strcopy(buffer, maxlength, "models/weapons/c_models/c_xms_cold_shoulder/c_xms_cold_shoulder.mdl");
		default: strcopy(buffer, maxlength, "models/weapons/c_models/c_knife/c_knife.mdl"); // fallback / default knife
	}
}

stock int CreateThrownKnife(int client)
{
    ClientSwitchWeaponSlot(client, TFWeaponSlot_Primary);

    int entity = CreateEntityByName("tf_projectile_syringe"); // Works fine... if we ignore that we dont have m_flDamage :/
    if (!IsValidEntity(entity))
    {
        LogError("There was an error trying to create tf_projectile_syringe throwing_knives.sp");
        return -1;
    }

    float pos[3], ang[3], vel[3];

    GetClientEyePosition(client, pos);
    GetClientEyeAngles(client, ang);

    float speed = 900.0;

    vel[0] = Cosine(DegToRad(ang[0])) * Cosine(DegToRad(ang[1])) * speed;
    vel[1] = Cosine(DegToRad(ang[0])) * Sine(DegToRad(ang[1])) * speed;
    vel[2] = -Sine(DegToRad(ang[0])) * speed;
    
    DispatchSpawn(entity);

    SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
    SetEntProp(entity, Prop_Send, "m_iTeamNum", TF2_GetClientTeam(client));

    knifeState[entity].projectileRef = EntIndexToEntRef(entity);
    knifeState[entity].weaponDefIndex = GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee);

    char model[PLATFORM_MAX_PATH];
    GetKnifeModel(knifeState[entity].weaponDefIndex, model, sizeof(model));
    SetEntityModel(entity, model);
    CreateTimer(0.1, Timer_KnifeSpin, EntIndexToEntRef(entity), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    TeleportEntity(entity, pos, ang, vel);

    SDKHook(entity, SDKHook_StartTouch, OnKnifeStartTouch);
    //RequestFrame(knifeNextFrame, entity);
    SetViewmodelAnimation(client, "throw_fire");
    EmitSoundToAll("weapons/cleaver_throw.wav", client, SNDCHAN_STATIC, 80, _, 1.0);
    return entity;
}

public Action Timer_KnifeSpin(Handle spin, int ref)
{
    int entity = EntRefToEntIndex(ref);
	if (IsValidEntity(entity))
	{
		float ang[3];
		GetEntPropVector(entity, Prop_Data, "m_angRotation", ang);
		ang[0] += 80.0;
		TeleportEntity(entity, NULL_VECTOR, ang, NULL_VECTOR);
		
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

Action Knives_OnWeaponCanSwitchTo(int client, int weapon)
{
    if (GetGameTime() >= abilityState[client].meleeCooldown)
        return Plugin_Continue;

    if (weapon == GetPlayerWeaponSlot(client, TFWeaponSlot_Melee))
        return Plugin_Handled;

    return Plugin_Continue;
}

public void OnKnifeStartTouch(int entity, int other)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

	bool validOwner = IsValidClientIndex(owner);

	if (other == owner)
        return;

	bool hitPlayer = IsValidClientIndex(other);

	if (hitPlayer && validOwner)
	{
        EmitSoundToAll("weapons/cleaver_hit_02.wav", entity, SNDCHAN_STATIC, 80, _, 1.0);
        switch(GetKnifeEffect(knifeState[entity].weaponDefIndex))
        {
            // The syringe does 25 damage on impact by default so you should have that into account when changing damage values.
            case KnifeEffect_DeepWound: ApplyKnifeHit(owner, other, _, _, _, 50.0, true, 5.0, 5.0, 0.2); // Less bleed damage but faster ticks = 195 total.
            case KnifeEffect_Heal: ApplyKnifeHit(owner, other, TFCond_RuneVampire, 3.0, _, 50.0, true, 10.0, 5.0); // 115 dmg.
            case KnifeEffect_Speed: ApplyKnifeHit(owner, other, TFCond_SpeedBuffAlly, 3.0, _, 50.0, true, 10.0, 5.0); // 115 dmg.
            case KnifeEffect_Cloak: ApplyKnifeHit(owner, other, TFCond_Stealthed, 3.0, _, 50.0, true, 10.0, 5.0); // 115 dmg.
            case KnifeEffect_Freeze: ApplyKnifeHit(owner, other, TFCond_FreezeInput, 0.3, true, 50.0); // 50 dmg, no bleeding & apply cond to enemy.
            default: return;
        }
	}
    else
    {
        EmitSoundToAll("weapons/cleaver_hit_world.wav", entity, SNDCHAN_STATIC, 80, _, 1.0);
    }
}

stock void ApplyKnifeHit(int attacker, int victim, TFCond condition = view_as<TFCond>(-1), float duration = 0.0, bool applyCondToEnemy = false, float damage, bool shouldApplyBleed = false, float bleedDamagePerTick = 0.0, float bleedDuration = 0.0, float bleedTickInterval = 1.0)
{
    if(!IsPlayerAlive(attacker) || !IsPlayerAlive(victim))
        return;
    
    SDKHooks_TakeDamage(victim, attacker, attacker, damage, DMG_SLASH);

    if (condition != view_as<TFCond>(-1) && duration > 0.0)
    {
        if (applyCondToEnemy)
            TF2_AddCondition(victim, condition, duration, attacker);
        else
            TF2_AddCondition(attacker, condition, duration, attacker);
    }

    if (!shouldApplyBleed)
        return;
    
    DataPack pack;
	CreateDataTimer(bleedTickInterval, Timer_BleedTick, pack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(GetClientUserId(attacker));
	pack.WriteCell(GetClientUserId(victim));
	pack.WriteFloat(bleedDamagePerTick);
	pack.WriteFloat(GetGameTime() + bleedDuration);
}

public Action Timer_BleedTick(Handle timer, DataPack pack)
{
	pack.Reset();
	int attacker = GetClientOfUserId(pack.ReadCell());
	int victim = GetClientOfUserId(pack.ReadCell());
	float bleedDamagePerTick = pack.ReadFloat();
	float bleedEndTime = pack.ReadFloat();

	if (!IsValidClient(victim) || !IsPlayerAlive(victim) || GetGameTime() >= bleedEndTime)
		return Plugin_Stop;

	SDKHooks_TakeDamage(victim, attacker, attacker, bleedDamagePerTick, DMG_SLASH | DMG_PREVENT_PHYSICS_FORCE);

	return Plugin_Continue;
}