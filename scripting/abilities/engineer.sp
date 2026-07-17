// TOGGLES
ConVar cvarShouldEngineerMoveOnPreround;

ConVar cvarPomsonHasKnockback;
ConVar cvarPomsonHasPenetration;
ConVar cvarPomsonHasAirshotStreak;

// SPECIFIC CONVARS
ConVar cvarEngineerPreroundSpeed;

ConVar cvarSentryGlowType;
ConVar cvarSentryMaxGlowTime;
ConVar cvarSentryGlowTimeToAdd;

ConVar cvarPomsonKnockbackVertical;
ConVar cvarPomsonKnockbackHorizontal;
ConVar cvarPomsonDamagePerStack;

enum
{
    Glow_None = 0,
    Glow_Sentry = (1 << 0),
    Glow_Mini   = (1 << 1)
};


public Action Timer_GiveEngineersSpeed(Handle hTimer)
{
	for (int client = 1; client <= MaxClients; client++)
    {
		if (GameRules_GetRoundState() == RoundState_RoundRunning)
			return Plugin_Stop;
        if (!IsValidClient(client) || !IsPlayerAlive(client))
            continue;
        #if defined VSH
        if (TF2_GetClientTeam(client) != TFTeam_Red)
            continue;
        #endif
		if(TF2_GetPlayerClass(client) != TFClass_Engineer)
			continue;
		
		int weapon = GetIndexOfWeaponSlot(client, TFWeaponSlot_Secondary);
		if (FindItemInArray(weapon, {22, 209, 160, 294, 15013, 15018, 15035, 15041, 15046, 15056, 30666}, 11)) // Pistols
		{
			SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", cvarEngineerPreroundSpeed.FloatValue);
		}
	}
	return Plugin_Continue;
}