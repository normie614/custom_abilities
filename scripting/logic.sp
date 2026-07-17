public Action LogicTimer(Handle hTimer) // This handles logic, like abilities, text shown to player, etc.
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (!IsValidClient(client) || !IsPlayerAlive(client))
            continue;
        #if defined VSH
        if (TF2_GetClientTeam(client) != TFTeam_Red)
            continue;
        #endif

        SetGlobalTransTarget(client);

        // Some vars so i dont repeat getIndex too much

        int primaryWeaponIndex = GetIndexOfWeaponSlot(client, TFWeaponSlot_Primary);
		int secondaryWeaponIndex = GetIndexOfWeaponSlot(client, TFWeaponSlot_Secondary);
		int meleeWeaponIndex = GetIndexOfWeaponSlot(client, TFWeaponSlot_Melee);
		//int PDAWeaponIndex = GetIndexOfWeaponSlot(client, TFWeaponSlot_PDA);
		// int primaryWeaponSlot = GetPlayerWeaponSlot(client, 0);
		// int meleeWeaponSlot	= GetPlayerWeaponSlot(client, 2);

        // Im gonna use PlayerClass to find stuff easily later...
        if (TF2_GetPlayerClass(client) == TFClass_Scout)
		{
            if (cvarCritacolaGivesCrits.IntValue != 0 && TF2_IsPlayerInCondition(client, TFCond_CritCola))
            {
                TF2_AddCondition(client, TFCond_CritCanteen, 0.3);
            }
            if (cvarSunOnAStickAbility.BoolValue && meleeWeaponIndex == 349) // Sun-on-a-Stick
            {
                HandleProgressAbility(client, HUD_BOTTOM, abilityState[client].meleeProgress, cvarSunOnAStickDMG.FloatValue,
                "Fireball Ready [M3]", "Fireball: %.0f%%", abilityState[client].meleeAvailable);
            }
        }

        if (TF2_GetPlayerClass(client) == TFClass_DemoMan)
        {
            if (cvarGrenadeLauncherHasModes.BoolValue && FindItemInArray(primaryWeaponIndex, {19, 206, 1007}, 3) && IsWeaponSlotActive(client, TFWeaponSlot_Primary)) // Grenade Launcher | Default, Strange, Festive
            {
                ShowAbilityHud(HUD_TOP, client, false, "Mode: %s [M3]", grenadeLauncherModeNames[grenadeLauncherMode[client]]);
            }
            if (cvarIronBomberHasHitStreak.BoolValue && primaryWeaponIndex == 1151) // Iron Bomber
            {
                float currentTime = GetGameTime();
                float timeRemaining = cvarIronBomberHitStreakTimeout.FloatValue - (GetGameTime() - abilityState[client].weaponLastHitTime);

                if(currentTime - abilityState[client].weaponLastHitTime < cvarIronBomberHitStreakTimeout.FloatValue)
                {
                    ShowAbilityHud(HUD_TOP, client, false, "Streak: %d | Damage bonus: +%.1f%% | %.1f",
                    abilityState[client].weaponHitStreak, abilityState[client].weaponHitStreak * cvarIronBomberDamagePerStack.FloatValue * 100.0, timeRemaining);
                }
            }
        }

        if (TF2_GetPlayerClass(client) == TFClass_Engineer)
        {
            float currentTime = GetGameTime();
            float timeRemaining = 1.5 - (GetGameTime() - abilityState[client].weaponLastHitTime);

            if(currentTime - abilityState[client].weaponLastHitTime < 1.5)
            {
                ShowAbilityHud(HUD_TOP, client, false, "Streak: %d | Damage bonus: +%.1f%% | %.1f",
                abilityState[client].weaponHitStreak, abilityState[client].weaponHitStreak * cvarPomsonDamagePerStack.FloatValue * 100.0, timeRemaining);
            }
        }

        if (TF2_GetPlayerClass(client) == TFClass_Medic)
        {
            if (cvarCrossbowAbility.BoolValue && FindItemInArray(primaryWeaponIndex, {305, 1079}, 2)) // Crossbows
            {
                HandleProgressAbility(client, HUD_TOP, abilityState[client].primaryProgress, cvarCrossbowDMG.FloatValue,
                "Explosive arrows: ✓", "Explosive arrows: %.0f%%", abilityState[client].hasExplosiveArrows);
            }
            if (cvarMedigunAbility.BoolValue && FindItemInArray(secondaryWeaponIndex, {29, 796, 805, 885, 894, 903, 912, 961, 970}, 9)) // Default medigun and reskins
            {
                HandleCooldownAbility(client, HUD_MIDDLE, abilityState[client].secondaryCooldown, "Healing Grenade: ✓ [M3]", "Cooldown: %.1f", true);
                // An example of a *ready to use* sound could be: "playgamesound items/medshotno1.wav" or "playgamesound items/gunpickup2.wav" - This is the default one if set to true with not custom path.
            }
            if(cvarQuickFixAbility.BoolValue && secondaryWeaponIndex == 411) // The Quick-Fix
            {
                HandleProgressAbility(client, HUD_MIDDLE, abilityState[client].healingDone, cvarQuickFixHealingRequired.FloatValue,
                "Personal Uber [M3]", "Personal Uber %.1f%%", abilityState[client].secondaryAvailable);
            }
            if (cvarVaccinatorAbility.BoolValue && secondaryWeaponIndex == 998) // The Vaccinator
            {
                HandleCooldownAbility(client, HUD_MIDDLE, abilityState[client].secondaryCooldown, "Shield: ✓ [M3]", "Cooldown: %.1f", true);
            }
        }

        if (TF2_GetPlayerClass(client) == TFClass_Spy)
        {
            if (cvarKnifeThrowAbility.BoolValue)
            {
                HandleCooldownAbility(client, HUD_BOTTOM, abilityState[client].meleeCooldown, "Knife: ✓ [M3]", "Cooldown: %.1f", true);
            }
        }
    }
    return Plugin_Continue;
}