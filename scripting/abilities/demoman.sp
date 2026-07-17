// TOGGLES
ConVar cvarGrenadeLauncherHasModes;
ConVar cvarIronBomberHasHitStreak;

// SPECIFIC CONVARS
ConVar cvarIronBomberHitStreakTimeout;
ConVar cvarIronBomberMaxStacks;
ConVar cvarIronBomberDamagePerStack;
ConVar cvarIronBomberStacksWithSplash;

enum GrenadeLauncherModeType
{
	GrenadeLauncher_Round = 0,
    GrenadeLauncher_Spray,
    GrenadeLauncher_Charge
};
GrenadeLauncherModeType grenadeLauncherMode[MAXPLAYERS + 1];
char grenadeLauncherModeNames[][16] =
{
	"Round",
    "Spray",
    "Charge"
};

void GrenadeLauncher_ChangeMode(int weapon, GrenadeLauncherModeType mode)
{
	// Reset everything to defaults. Atleast I hope it does...
    TF2Attrib_RemoveByName(weapon, "projectile spread angle penalty");
    TF2Attrib_RemoveByName(weapon, "fire rate bonus");
    TF2Attrib_RemoveByName(weapon, "Projectile range increased");

	switch (mode)
    {
		case GrenadeLauncher_Round:
        {
            TF2Attrib_SetByName(weapon, "fire rate bonus", 0.9);
            TF2Attrib_SetByName(weapon, "Projectile range increased", 1.3);
        }
		
        case GrenadeLauncher_Spray:
        {
            TF2Attrib_SetByName(weapon, "fire rate bonus", -9.0);
            TF2Attrib_SetByName(weapon, "projectile spread angle penalty", 6.0);
        }

        case GrenadeLauncher_Charge:
        {
            TF2Attrib_SetByName(weapon, "fire rate bonus", -9.0);
            TF2Attrib_SetByName(weapon, "projectile spread angle penalty", 0.0);
        }
    }
}