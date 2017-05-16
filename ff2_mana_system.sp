#include <tf2_stocks>
#include <sdkhooks>
#include <freak_fortress_2>

public Plugin myinfo = {
	name 		= "Freak Fortress 2: Mana System",
	description = "Uses config changes to give a mana pool from which to use abilities",
	author 		= "Deathreus",
	version 	= "0.1"
};

#define DEBUG

 #undef MAXPLAYERS
#define MAXPLAYERS 33

#define INACTIVE 10000000.0

bool UseManaThisRound[MAXPLAYERS];
float ManaPoolMax[MAXPLAYERS];
float ManaPerSecond[MAXPLAYERS];
float ManaCost[MAXPLAYERS][10];
char ManaAbility[MAXPLAYERS][10][128];
char ManaPlugin[MAXPLAYERS][10][128];

float ManaPoolCurrent[MAXPLAYERS];

float ManaNextTick[MAXPLAYERS];

Handle rageHUD

public void OnPluginStart()
{
	HookEvent("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
	
	char sCmd[6];
	for(int iSlot = 1; iSlot <= 9; iSlot++)
	{
		Format(sCmd, 6, "slot%i", iSlot);
		AddCommandListener(CastAbility, sCmd);
	}
	
	rageHUD = CreateHudSynchronizer();
}

public void OnClientDisconnect(int iClient)
{
	UseManaThisRound[iClient] = false;
	ManaPoolMax[iClient] = 0.0;
	ManaPerSecond[iClient] = 0.0;
	ManaPoolCurrent[iClient] = 0.0;
	ManaNextTick[iClient] = INACTIVE;
	
	for(new iSlot = 1; iSlot <= 9; iSlot++)
	{
		ManaCost[iClient][iSlot] = 0.0;
		ManaAbility[iClient][iSlot][0] = '\0';
		ManaPlugin[iClient][iSlot][0] = '\0';
	}
}

public void OnRoundStart(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	for(int iIndex; iIndex < MAXPLAYERS; iIndex++)
	{
		int iBoss = GetClientOfUserId(FF2_GetBossUserId(iIndex));
		KeyValues kv = view_as<KeyValues>(FF2_GetSpecialKV(iIndex));
		if(kv)
		{
			if(kv.GetFloat("mana_max") != 0.0)
			{
				UseManaThisRound[iBoss] = true;
				
				ManaPoolMax[iBoss] = kv.GetFloat("mana_max");
				ManaPerSecond[iBoss] = kv.GetFloat("mana_regen");
				
				if(ManaPoolMax[iBoss] <= 0.0 || ManaPerSecond[iBoss] <= 0.0)
				{	// Break if we got invalid numbers
					UseManaThisRound[iBoss] = false;
					return;
				}
				
				#if defined DEBUG
				LogMessage("Max mana for boss %N is %.0f, and regenerates at %.0f per second", iBoss, ManaPoolMax[iBoss], ManaPerSecond[iBoss]);
				#endif
				
				ManaNextTick[iBoss] = GetEngineTime() + 0.2;
				SDKHook(iBoss, SDKHook_PreThink, ManaThink);
				
				char sAbility[12];
				for(int iSlot = 1; iSlot <= 9; iSlot++)
				{
					for(int i = 1; i <= 16; i++)
					{
						Format(sAbility, 12, "ability%i", i);
						if(kv.JumpToKey(sAbility))
						{
							if(!kv.GetNum("mana_slot") || kv.GetNum("mana_slot") != iSlot)
								continue;
							
							kv.GetString("name", ManaAbility[iBoss][iSlot], 128);
							kv.GetString("plugin_name", ManaPlugin[iBoss][iSlot], 128);
							ManaCost[iBoss][iSlot] = kv.GetFloat("mana_cost");
							
							#if defined DEBUG
							LogMessage("Ability name = %s, cost = %f, for slot %i", ManaAbility[iBoss][iSlot], ManaCost[iBoss][iSlot], iSlot);
							#endif
						}
					}
				}
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
			ManaPoolCurrent[iClient] = 0.0;
			SDKUnhook(iClient, SDKHook_PreThink, ManaThink);
		}
	}
}

public FF2_PreAbility(int iIndex, const char[] pluginName, const char[] abilityName, int iSlot, bool &bEnabled)
{
	int iBoss = GetClientOfUserId(FF2_GetBossUserId(iIndex));
	if(UseManaThisRound[iBoss] && iSlot == 0)
		bEnabled = false;
}

public void ManaThink(int iClient)
{
	if(FF2_GetRoundState() != 1 || !UseManaThisRound[iClient])
	{
		ManaNextTick[iClient] = INACTIVE;
		return;
	}
	
	if(ManaNextTick[iClient] <= GetEngineTime())
	{
		ManaPoolCurrent[iClient] += (ManaPerSecond[iClient] / 5.0);	// 5 updates per second
		if(ManaPoolCurrent[iClient] > ManaPoolMax[iClient]) // clamp
			ManaPoolCurrent[iClient] = ManaPoolMax[iClient];
		
		SetHudTextParams(-1.0, 0.83, 0.15, 255, 255, 255, 255);
		ShowSyncHudText(iClient, rageHUD, "Mana: %.0f / %.0f", ManaPoolCurrent[iClient], ManaPoolMax[iClient]);
		
		FF2_SetBossCharge(FF2_GetBossIndex(iClient), 0, 100.0);
		
		ManaNextTick[iClient] = GetEngineTime() + 0.2;
	}
}

public Action CastAbility(int iClient, const char[] sCmd, int nArgs)
{
	int iBoss = FF2_GetBossIndex(iClient)
	if(iBoss < 0 || !UseManaThisRound[iClient])
		return Plugin_Continue;
	
	char sSlot[6];
	for(int iSlot = 1; iSlot <= 9; iSlot++)
	{
		Format(sSlot, 6, "slot%i", iSlot);
		if(!strcmp(sCmd, sSlot))
		{
			FF2_DoAbility(iBoss, ManaPlugin[iClient][iSlot], ManaAbility[iClient][iSlot], 0, 0);
			ManaPoolCurrent[iClient] -= ManaCost[iClient][iSlot];
			
			#if defined DEBUG
			LogMessage("Using ability %s from %s, taking %.0f mana away", ManaAbility[iClient][iSlot], ManaPlugin[iClient][iSlot], ManaCost[iClient][iSlot]);
			#endif
		}
	}
	
	return Plugin_Handled;
}
