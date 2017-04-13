#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>

public Plugin myinfo = {
	name 		= "Freak Fortress 2: Mana System",
	description = "Uses config changes to give a mana pool from which to use abilities",
	author 		= "Deathreus",
	version 	= "0.1"
};

bool UseManaThisRound[MAXPLAYERS];
float ManaMax[MAXPLAYERS];
float ManaPerSecond[MAXPLAYERS];

public void OnPluginStart()
{
}

public void OnRoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
}

public void OnRoundEnd(Event hEvent, const char[] sName, bool bDontBroadcast)
{
}
