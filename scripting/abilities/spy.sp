/*
    INCLUDED IN: UTILS.SP
    USE LOCATIONS:
        * StartKamikaze(int client) => Events.sp | OnPlayerRunCmd
*/

// TOGGLES
ConVar cvarDiamondBackAbility;
ConVar cvarSapperKamikazeAbility;
ConVar cvarKnifeThrowAbility;

// SPECIFIC CONVARS
ConVar cvarDiamondbackAmmoToGive;
ConVar cvarDiamondbackAllowAmmoPickup;
ConVar cvarDiamondbackStartingClip;
ConVar cvarDiamondbackEnhancedJump;

ConVar cvarKamikazeExplosionRange;
ConVar cvarKamikazeExplosionDamage;
ConVar cvarKamikazeTimeBeforeExplosion;
ConVar cvarKamikazeRunSpeed;

ConVar cvarKnifeThrowAbilityCooldown;

Handle KamikazeTimer[MAXPLAYERS + 1];

float KamikazeEndTime[MAXPLAYERS + 1];

char SpyRandomScreamList[][] =
{
    "vo/spy_sf12_scared01.mp3",
    "vo/spy_sf13_magic_reac02.mp3",
    "vo/spy_paincrticialdeath02.mp3",
    "vo/spy_paincrticialdeath03.mp3",
	"vo/spy_sf12_falling01.mp3",
	"vo/spy_laughevil01.mp3",
};

void StartKamikaze(int client)
{
    TF2_StunPlayer(client, cvarKamikazeTimeBeforeExplosion.FloatValue, 0.0, TF_STUNFLAG_THIRDPERSON | TF_STUNFLAG_NOSOUNDOREFFECT, 0);

    float duration = cvarKamikazeTimeBeforeExplosion.FloatValue;
    KamikazeEndTime[client] = GetGameTime() + duration;

    PlayRandomSoundToAll(SpyRandomScreamList, sizeof(SpyRandomScreamList));

    KamikazeTimer[client] = CreateTimer(0.1, Timer_Kamikaze, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Kamikaze(Handle timer, int client)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client))
    {
        KamikazeTimer[client] = null;
        return Plugin_Stop;
    }
    SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", cvarKamikazeRunSpeed.FloatValue); // Run for it little guy :)

    float clientPos[3];
    GetClientAbsOrigin(client, clientPos);
    float explosionRange = cvarKamikazeExplosionRange.FloatValue;
    TE_SetupBeamRingPoint(clientPos, explosionRange - 1.0, explosionRange, beamSprite, haloSprite, 0, 10, 0.11, 3.0, 0.0, {255, 255, 255, 255}, 10, 0);
    TE_SendToAll();
    TE_SetupBeamRingPoint(clientPos, 10.0, explosionRange, beamSprite, haloSprite, 0, 10, 0.1, 5.0, 0.0, {255, 0, 0, 200}, 10, 0);
    TE_SendToAll();

    float remaining = KamikazeEndTime[client] - GetGameTime();
    
    if (remaining <= cvarKamikazeTimeBeforeExplosion.FloatValue)
    {
        //TODO: Add a ticking sound or something similar...
    }

    if (remaining <= 0.0)
    {
        ArrayList targets = DetectEnemiesNearby(client, clientPos, explosionRange);
        int explosionDamage = cvarKamikazeExplosionDamage.IntValue;
        for (int i = 0; i < targets.Length; i++)
        {
            int target = targets.Get(i);
            DoDamage(client, target, explosionDamage);
        }

        delete targets;

        SpawnTempEntity("env_explosion", clientPos, "Explode");
        AttachParticle(client, "fluidSmokeExpl_ring_mvm");
        EmitSoundToAll("mvm/sentrybuster/mvm_sentrybuster_explode.wav", client);

        KamikazeTimer[client] = null;
        ForcePlayerSuicide(client, true);
    }
    return Plugin_Continue;
}