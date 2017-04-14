#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>

public Plugin myinfo = {
	name 		= "Freak Fortress 2: Mana System",
	description = "Uses config changes to give a mana pool from which to use abilities",
	author 		= "Deathreus",
	version 	= "0.1"
};

 #undef MAXPLAYERS
#define MAXPLAYERS 33

#define INACTIVE 10000000.0

bool UseManaThisRound[MAXPLAYERS];
float ManaPoolMax[MAXPLAYERS];
float ManaPerSecond[MAXPLAYERS];
float ManaCost[MAXPLAYERS][10];

float ManaPoolCurrent[MAXPLAYERS];

float ManaNextTick[MAXPLAYERS];

Handle rageHUD

public void OnPluginStart()
{
	HookEvent("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
	
	char sCmd[6];
	for(int i = 1; i <= 9; i++)
	{
		Format(sCmd, 6, "slot%i", i);
		AddCommandListener(CastAbility, sCmd);
	}
	
	rageHUD = CreateHudSynchronizer();
}

public void OnRoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	for(int iIndex; iIndex < MAXPLAYERS; iIndex++)
	{
		int iBoss = GetClientOfUserId(FF2_GetBossUserId(iIndex));
		KeyValues kv = view_as<KeyValues>(FF2_GetSpecialKV(iIndex));
		if(kv)
		{
			if(kv.JumpToKey("mana_max"))
			{
				UseManaThisRound[iBoss] = true;
				
				ManaPoolMax[iBoss] = kv.GetFloat("mana_max");
				ManaPerSecond[iBoss] = kv.GetFloat("mana_regen");
				
				SDKHook(iBoss, SDKHook_PreThink, ManaThink);
				
				int i = 1;
				char sAbility[] = "ability1";
				do
				{
					i++
					Format(sAbility, 12, "ability%i", i);
					
					if(kv.GetNum("mana_slot") != i)
						continue;
					
					ManaCost[iBoss][i] = kv.GetFloat("mana_cost");
				}
				while (kv.JumpToKey(sAbility))
			}
		}
	}
}

public void OnRoundEnd(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	for(int iClient = MaxClients; iClient > 0; iClient--)
	{
		if(UseManaThisRound[iClient])
		{
			UseManaThisRound[iClient] = false;
			SDKUnhook(iClient, SDKHook_PreThink, ManaThink);
		}
	}
}

public FF2_PreAbility(int iIndex, const char[] pluginName, const char[] abilityName, int iSlot, bool &bEnabled)
{
	int iBoss = GetClientOfUserId(FF2_GetBossUserId(iIndex));
	if(UseManaThisRound[iBoss] && !iSlot)
		bEnabled = false;
}

public void ManaThink(int iClient)
{
	if(FF2_GetRoundState() != 1)
	{
		ManaNextTick[iClient] = INACTIVE;
		return;
	}
	
	if(ManaNextTick[iClient] <= GetEngineTime())
	{
		ManaPoolCurrent[iClient] += (ManaPerSecond[iClient] / 5.0);
		if(ManaPoolCurrent[iClient] > ManaPoolMax[iClient])
			ManaPoolCurrent[iClient] = ManaPoolMax[iClient];
		
		SetHudTextParams(-1.0, 0.83, 0.15, 255, 255, 255, 255);
		FF2_ShowSyncHudText(iClient, rageHUD, "Mana: %.0f", RoundFloat(ManaPoolCurrent[iClient]));
		
		ManaNextTick[iClient] = GetEngineTime() + 0.2;
	}
}

public Action CastAbility(int iClient, const char[] sCmd, int nArgs)
{
	char sSlot[6];
	for(int i = 1; i <= 9; i++)
	{
		Format(sSlot, 6, "slot%i", i);
		if(!strcmp(sCmd, sSlot))
		{
		}
	}
}
