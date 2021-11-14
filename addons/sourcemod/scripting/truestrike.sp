#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#include <clientprefs>
#pragma newdecls required
#pragma semicolon 1


public Plugin myinfo =
{
	name = "TrueStrike",
	author = "zer0.k",
	description = "Toggle ammo, recoil, inaccuracy and spread for CS:GO",
	version = "1.1.4",
	url = "https://github.com/zer0k-z/TrueStrike"
};

#define PREFIX " \x10TrueStrike \x01| "
bool gB_EnableTrueStrike[MAXPLAYERS + 1];
bool gB_JustTweakedCvars;
Handle gH_TrueStrikeCookie;

bool gB_DisableRecoil[MAXPLAYERS + 1];
ConVar gCV_weapon_recoil_scale;
float gF_weapon_recoil_scale_default = 2.0;
ConVar gCV_weapon_recoil_view_punch_extra;
float gF_weapon_recoil_view_punch_extra_default = 0.055;
Handle gH_RecoilCookie;

bool gB_DisableInaccuracy[MAXPLAYERS + 1];
// DynamicHook gH_GetInaccuracyHook;
ConVar gCV_weapon_accuracy_nospread;
bool gB_weapon_accuracy_nospread_default;
Handle gH_InaccuracyCookie;

bool gB_UseClientSeed[MAXPLAYERS + 1];
ConVar gCV_sv_usercmd_custom_random_seed;
bool gB_sv_usercmd_custom_random_seed_default = true;
Handle gH_SeedCookie;

bool gB_DisableSpread[MAXPLAYERS + 1];
DynamicHook gH_GetSpreadHook;
Handle gH_SpreadCookie;

int gI_EnableInfiniteAmmo[MAXPLAYERS + 1];
ConVar gCV_sv_infinite_ammo;
int gI_sv_infinite_ammo_default;
Handle gH_SDKCall_GetMaxClip1;
Handle gH_AmmoCookie;

bool gB_LateLoaded;

// ====================
// Plugin Events
// ====================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gB_LateLoaded = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVars();
	RegisterCookies();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		OnClientCookiesCached(i);
	}

	HookEvents();	
	RegConsoleCmd("sm_truestrike", CommandMenuTrueStrike);
	if (gB_LateLoaded)
	{
		HookWeaponEntities();
		HookClients();
	}
	HookConVars();
	UnsetReplicatedConVars();
}

public void OnConfigsExecuted()
{
	UpdateServerConVars();
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			UnreplicateConVars(i);
		}		
	}
	UnhookConVars();
	UntweakConVars();
	SetReplicatedConVars();
}
// ====================
// Client Events
// ====================

public void OnClientPutInServer(int client)
{
	HookClient(client);
}

public void SDKHook_OnClientPreThink(int client)
{
	// Cvar changes in here should not be hooked
	UnhookConVars();
	if (IsPlayerAlive(client))
	{	
		if (gB_EnableTrueStrike[client])
		{
			TweakConVars(client);
			gB_JustTweakedCvars = true;
		}
		else
		{
			UntweakConVars();
		}
	}
	HookConVars();
}

public void OnClientCookiesCached(int client)
{
	gB_EnableTrueStrike[client] = !!LoadCookie(client, gH_TrueStrikeCookie);
	gI_EnableInfiniteAmmo[client] = !!LoadCookie(client, gH_AmmoCookie);
	gB_DisableInaccuracy[client] = !!LoadCookie(client, gH_InaccuracyCookie);
	gB_DisableRecoil[client] = !!LoadCookie(client, gH_RecoilCookie);
	gB_UseClientSeed[client] = !!LoadCookie(client, gH_SeedCookie);
	gB_DisableSpread[client] = !!LoadCookie(client, gH_SpreadCookie);
}

public void OnPlayerRunCmdPost(int client)
{
	if (gB_JustTweakedCvars)
	{
		UnhookConVars();
		UntweakConVars();
		HookConVars();
		gB_JustTweakedCvars = false;
	}
}
// ====================
// Entity Events
// ====================
public void OnEntityCreated(int entity, const char[] classname)
{
	HookWeaponEntity(entity);
}

// ====================
// ConVars
// ====================

void CreateConVars()
{
	gCV_weapon_recoil_scale = FindConVar("weapon_recoil_scale");
	gCV_weapon_recoil_view_punch_extra = FindConVar("weapon_recoil_view_punch_extra");
	gCV_weapon_accuracy_nospread = FindConVar("weapon_accuracy_nospread");
	gCV_sv_usercmd_custom_random_seed = FindConVar("sv_usercmd_custom_random_seed");
	gCV_sv_infinite_ammo = FindConVar("sv_infinite_ammo");
}

void UpdateServerConVars()
{
	gF_weapon_recoil_scale_default = gCV_weapon_recoil_scale.FloatValue;
	gF_weapon_recoil_view_punch_extra_default = gCV_weapon_recoil_view_punch_extra.FloatValue;
	gB_weapon_accuracy_nospread_default = gCV_weapon_accuracy_nospread.BoolValue;
	gB_sv_usercmd_custom_random_seed_default = gCV_sv_usercmd_custom_random_seed.BoolValue;
	gI_sv_infinite_ammo_default = gCV_sv_infinite_ammo.IntValue;
}

void HookConVars()
{
	HookConVarChange(gCV_weapon_recoil_scale, OnConVarChanged);
	HookConVarChange(gCV_weapon_recoil_view_punch_extra, OnConVarChanged);
	HookConVarChange(gCV_weapon_accuracy_nospread, OnConVarChanged);
	HookConVarChange(gCV_sv_usercmd_custom_random_seed, OnConVarChanged);
	HookConVarChange(gCV_sv_infinite_ammo, OnConVarChanged);
}

void UnhookConVars()
{
	UnhookConVarChange(gCV_weapon_recoil_scale, OnConVarChanged);
	UnhookConVarChange(gCV_weapon_recoil_view_punch_extra, OnConVarChanged);
	UnhookConVarChange(gCV_weapon_accuracy_nospread, OnConVarChanged);
	UnhookConVarChange(gCV_sv_usercmd_custom_random_seed, OnConVarChanged);
	UnhookConVarChange(gCV_sv_infinite_ammo, OnConVarChanged);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char buffer[64];
	convar.GetString(buffer, sizeof(buffer));
	if (StrEqual(buffer, "weapon_recoil_scale"))
	{
		gF_weapon_recoil_scale_default = gCV_weapon_recoil_scale.FloatValue;
	}
	else if (StrEqual(buffer, "weapon_recoil_view_punch_extra"))
	{
		gF_weapon_recoil_view_punch_extra_default = gCV_weapon_recoil_view_punch_extra.FloatValue;
	}
	else if (StrEqual(buffer, "weapon_accuracy_nospread"))
	{
		gCV_weapon_accuracy_nospread = FindConVar("weapon_accuracy_nospread");
	}
	else if (StrEqual(buffer, "sv_usercmd_custom_random_seed"))
	{
		gCV_sv_usercmd_custom_random_seed = FindConVar("sv_usercmd_custom_random_seed");
	}
	else if (StrEqual(buffer, "sv_infinite_ammo"))
	{
		gI_sv_infinite_ammo_default = gCV_sv_infinite_ammo.IntValue;
	}
}

void ReplicateConVars(int client)
{
	gCV_weapon_recoil_scale.ReplicateToClient(client, gB_DisableRecoil[client] ? "0.0" : "2.0");
	gCV_weapon_recoil_view_punch_extra.ReplicateToClient(client, gB_DisableRecoil[client] ? "0.0" : "0.055");
	gCV_weapon_accuracy_nospread.ReplicateToClient(client, gB_DisableInaccuracy[client] ? "1" : "0");
	gCV_sv_infinite_ammo.ReplicateToClient(client, gI_EnableInfiniteAmmo[client] == 2 ? "2" : gI_EnableInfiniteAmmo[client] ? "1" : "0");
}

void TweakConVars(int client)
{
	gCV_weapon_recoil_scale.FloatValue = gB_DisableRecoil[client] ? 0.0 : 2.0;
	gCV_weapon_recoil_view_punch_extra.FloatValue = gB_DisableRecoil[client] ? 0.0 : 0.055;

	gCV_weapon_accuracy_nospread.IntValue = gB_DisableInaccuracy[client];

	gCV_sv_usercmd_custom_random_seed.IntValue = !gB_UseClientSeed[client];

	gCV_sv_infinite_ammo.IntValue = gI_EnableInfiniteAmmo[client];
}

void UntweakConVars()
{
	gCV_weapon_recoil_scale.FloatValue = gF_weapon_recoil_scale_default;
	gCV_weapon_recoil_view_punch_extra.FloatValue = gF_weapon_recoil_view_punch_extra_default;

	gCV_weapon_accuracy_nospread.IntValue = gB_weapon_accuracy_nospread_default;

	gCV_sv_usercmd_custom_random_seed.IntValue = gB_sv_usercmd_custom_random_seed_default;

	gCV_sv_infinite_ammo.IntValue = gI_sv_infinite_ammo_default;
}

void UnreplicateConVars(int client)
{
	char buffer[32];
	FloatToString(gF_weapon_recoil_scale_default, buffer, sizeof(buffer));
	gCV_weapon_recoil_scale.ReplicateToClient(client, buffer);
	FloatToString(gF_weapon_recoil_view_punch_extra_default, buffer, sizeof(buffer));
	gCV_weapon_recoil_view_punch_extra.ReplicateToClient(client, buffer);
	IntToString(gB_weapon_accuracy_nospread_default, buffer, sizeof(buffer));
	gCV_weapon_accuracy_nospread.ReplicateToClient(client, buffer);
	IntToString(gI_sv_infinite_ammo_default, buffer, sizeof(buffer));
	gCV_sv_infinite_ammo.ReplicateToClient(client, buffer);
}

void UnsetReplicatedConVars()
{
	UnsetReplicatedConVar(gCV_weapon_recoil_scale);
	UnsetReplicatedConVar(gCV_weapon_recoil_view_punch_extra);
	UnsetReplicatedConVar(gCV_weapon_accuracy_nospread);
	UnsetReplicatedConVar(gCV_sv_infinite_ammo);
}

void UnsetReplicatedConVar(ConVar convar)
{
	int flags = convar.Flags;
	flags &= ~FCVAR_REPLICATED;
	convar.Flags = flags;
}

void SetReplicatedConVars()
{
	SetReplicatedConVar(gCV_weapon_recoil_scale);
	SetReplicatedConVar(gCV_weapon_recoil_view_punch_extra);
	SetReplicatedConVar(gCV_weapon_accuracy_nospread);
	SetReplicatedConVar(gCV_sv_infinite_ammo);
}

void SetReplicatedConVar(ConVar convar)
{
	int flags = convar.Flags;
	flags |= FCVAR_REPLICATED;
	convar.Flags = flags;
}

// ====================
// Hooks & Callbacks
// ====================

void HookEvents()
{
	GameData gameData = LoadGameConfigFile("truestrike.games");
	gH_GetSpreadHook = DynamicHook.FromConf(gameData, "GetSpread");
	if (gH_GetSpreadHook == INVALID_HANDLE)
	{
		SetFailState("Failed to hook CWeaponCSBase::GetSpread.");
	}
	/* Unused
	gH_GetInaccuracyHook = DynamicHook.FromConf(gameData, "GetInaccuracy");
	if (gH_GetInaccuracyHook == INVALID_HANDLE)
	{
		SetFailState("Failed to hook CWeaponCSBase::GetInaccuracy.");
	}
	*/
	StartPrepSDKCall(SDKCall_Entity);
	if(!PrepSDKCall_SetFromConf(gameData, SDKConf_Virtual, "GetMaxClip1"))
    {
        SetFailState("PrepSDKCall_SetFromConf failed for GetMaxClip1");
    }
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	gH_SDKCall_GetMaxClip1 = EndPrepSDKCall();

	delete gameData;

	HookEvent("weapon_fire", OnWeaponFire, EventHookMode_Post);
}

void HookWeaponEntities()
{
	int entity = 0;
	while ((entity = FindEntityByClassname(entity, "weapon_*")) != -1)
	{
		HookWeaponEntity(entity);
	}
}

void HookWeaponEntity(int entity)
{
	if (!IsValidEdict(entity) || !IsValidEntity(entity))
	{
		return;
	}
	char buffer[32];
	GetEdictClassname(entity, buffer, sizeof(buffer));
	if (StrContains(buffer, "weapon_") != -1)
	{
		if (gH_GetSpreadHook.HookEntity(Hook_Pre, entity, DHooks_OnGetSpread) == INVALID_HOOK_ID)
		{
			SetFailState("Failed to hook CWeaponCSBase::GetSpread for '%s'!", buffer);
		}
		/*
		if (gH_GetInaccuracyHook.HookEntity(Hook_Pre, entity, DHooks_OnGetInaccuracy) != INVALID_HOOK_ID)
		{
			PrintToServer("CWeaponCSBase::GetInaccuracy hooked successfully for '%s'!", classname);
		}
		*/
	}
}

void HookClients()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		HookClient(i);
	}
}

void HookClient(int client)
{
	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		SDKHook(client, SDKHook_PreThink, SDKHook_OnClientPreThink);
		if ((gB_DisableInaccuracy[client] || gB_DisableRecoil[client] || gI_EnableInfiniteAmmo[client]) && gB_EnableTrueStrike[client])
		{
			ReplicateConVars(client);
		}
		if (!gB_EnableTrueStrike[client])
		{
			UnreplicateConVars(client);
		}
	}
	
}

public MRESReturn DHooks_OnGetSpread(int pThis, DHookReturn hReturn)
{
	int client = GetEntPropEnt(pThis, Prop_Data, "m_hOwnerEntity");
	if (gB_DisableSpread[client] && gB_EnableTrueStrike[client])
	{
		hReturn.Value = 0.0;
		return MRES_Supercede;
	}
	else
	{
		return MRES_Ignored;
	}
}

public Action OnWeaponFire(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!gB_EnableTrueStrike[client])
	{
		return Plugin_Handled;
	}

	int weapon_entity_index = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (gI_EnableInfiniteAmmo[client])
	{
		SetMinAmmo(weapon_entity_index);
	}
	return Plugin_Handled;
}

// Unused, seting weapon_accuracy_nospread to 0 during PreThink instead of this.
/*
public MRESReturn DHooks_OnGetInaccuracy(int pThis, DHookReturn hReturn)
{

	int client = GetEntPropEnt(pThis, Prop_Data, "m_hOwnerEntity");
	if (gB_DisableInaccuracy[client])
	{
		hReturn.Value = 0.0;
		return MRES_Supercede;
	}
	else
	{
		return MRES_Ignored;
	}
}
*/

// TrueStrike //

void ToggleTrueStrike(int client)
{
	gB_EnableTrueStrike[client] = !gB_EnableTrueStrike[client];
	SetCookie(client, gH_TrueStrikeCookie, gB_EnableTrueStrike[client]);
	PrintToChat(client, "%sTrueStrike %s.", PREFIX, gB_EnableTrueStrike[client] ? "enabled" : "disabled");
	if (gB_EnableTrueStrike[client])
	{
		ReplicateConVars(client);
	}
	else
	{
		UnreplicateConVars(client);
	}
}

// Seed //

void ToggleSeed(int client)
{
	gB_UseClientSeed[client] = !gB_UseClientSeed[client];
	SetCookie(client, gH_SeedCookie, gB_UseClientSeed[client]);
	PrintToChat(client, "%s%s", PREFIX, gB_UseClientSeed[client] ? "Bullet prediction is now shared between server and client. \x0ENote\x01: This will not work perfectly if spread is disabled!" : "Bullet prediction is no longer shared between server and client.");
}

// Recoil //

void ToggleRecoil(int client)
{
	gB_DisableRecoil[client] = !gB_DisableRecoil[client];
	SetCookie(client, gH_RecoilCookie, gB_DisableRecoil[client]);
	PrintToChat(client, "%sWeapon recoil %s.", PREFIX, gB_DisableRecoil[client] ? "disabled" : "enabled");
	ReplicateConVars(client);
}

// Inaccuracy (what weapon_accuracy_nospread actually does, ironically) //

void ToggleInaccuracy(int client)
{
	gB_DisableInaccuracy[client] = !gB_DisableInaccuracy[client];
	SetCookie(client, gH_InaccuracyCookie, gB_DisableInaccuracy[client]);
	PrintToChat(client, "%sWeapon inaccuracy %s.", PREFIX, gB_DisableInaccuracy[client] ? "disabled" : "enabled");
	ReplicateConVars(client);
}

// Spread //

void ToggleSpread(int client)
{
	gB_DisableSpread[client] = !gB_DisableSpread[client];
	SetCookie(client, gH_SpreadCookie, gB_DisableSpread[client]);
	PrintToChat(client, "%sSpread %s.", PREFIX, gB_DisableSpread[client] ? "disabled" : "enabled");
}

// Ammo //

void ToggleAmmo(int client)
{
	switch (gI_EnableInfiniteAmmo[client])
	{
		case 0:
		{
			gI_EnableInfiniteAmmo[client] = 1;
			PrintToChat(client, "%sInfinite clip ammo enabled.", PREFIX);
		}
		case 1:
		{
			gI_EnableInfiniteAmmo[client] = 2;
			PrintToChat(client, "%sInfinite reserve ammo enabled.", PREFIX);
		}
		case 2:
		{
			gI_EnableInfiniteAmmo[client] = 0;
			PrintToChat(client, "%sInfinite ammo disabled.", PREFIX);
		}
	}
	ReplicateConVars(client);
	SetCookie(client, gH_AmmoCookie, gI_EnableInfiniteAmmo[client]);
	CheckAmmo(client);
}

int GetMaxClip(int weaponEnt)
{
	return SDKCall(gH_SDKCall_GetMaxClip1, weaponEnt);
}

void CheckAmmo(int client)
{
	if (gI_EnableInfiniteAmmo[client])
	{
		SetAllMinAmmo(client);
	}

}

/* No longer used
void SetAllMaxClip(int client)
{
	for (int i = 0; i <= 4; i++)
	{
		int weapon_ent = GetPlayerWeaponSlot(client, i);
		SetMaxClip(weapon_ent);
	}
}

void SetMaxClip(int weaponEnt, int add = 0)
{
	if (weaponEnt != -1)
	{
		// Need to add 1 upon firing, else you would be one bullet fewer than max clip
		// ...but not upon checking.
		SetEntProp(weaponEnt, Prop_Send, "m_iClip1", GetMaxClip(weaponEnt) + add);
	}
}
*/

void SetMinAmmo(int weaponEnt)
{
	if (weaponEnt != -1)
	{
		int reserveAmmo = GetEntProp(weaponEnt, Prop_Send, "m_iPrimaryReserveAmmoCount");

		if (reserveAmmo < GetMaxClip(weaponEnt))
		{
			SetEntProp(weaponEnt, Prop_Send, "m_iPrimaryReserveAmmoCount", GetMaxClip(weaponEnt));
		}
	}
}

void SetAllMinAmmo(int client)
{
	for (int i = 0; i <= 4; i++)
	{
		int weapon_ent = GetPlayerWeaponSlot(client, i);
		SetMinAmmo(weapon_ent);
	}
}

// ====================
// Menu
// ====================

public Action CommandMenuTrueStrike(int client, int args)
{
	Menu_TrueStrike(client);
	return Plugin_Handled;
}

void Menu_TrueStrike(int client)
{
	Menu menu = new Menu(Menu_TrueStrike_Handler);
	menu.SetTitle("TrueStrike Menu");
	char buffer[32];

	FormatEx(buffer, sizeof(buffer), "TrueStrike - %s", gB_EnableTrueStrike[client] ? "Enabled" : "Disabled");
	menu.AddItem("TrueStrike", buffer);
	if (gB_EnableTrueStrike[client])
	{
		FormatEx(buffer, sizeof(buffer), "Inaccuracy - %s", gB_DisableInaccuracy[client] ? "Disabled" : "Enabled");
		menu.AddItem("Inaccuracy", buffer);

		FormatEx(buffer, sizeof(buffer), "Spread - %s", gB_DisableSpread[client] ? "Disabled" : "Enabled");
		menu.AddItem("Spread", buffer);

		FormatEx(buffer, sizeof(buffer), "Recoil - %s", gB_DisableRecoil[client] ? "Disabled" : "Enabled");
		menu.AddItem("Recoil", buffer);

		FormatEx(buffer, sizeof(buffer), "Bullet Prediction - %s", gB_UseClientSeed[client] ? "Shared" : "Independent");
		menu.AddItem("Seed", buffer);

		FormatEx(buffer, sizeof(buffer), "Infinite Ammo - %s", gI_EnableInfiniteAmmo[client] == 2 ? "Reserve" : gI_EnableInfiniteAmmo[client] ? "Clip" : "Disabled");
		menu.AddItem("Ammo", buffer);
	}
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int Menu_TrueStrike_Handler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if (StrEqual(info, "TrueStrike"))
		{
			ToggleTrueStrike(param1);
		}
		else if (StrEqual(info, "Inaccuracy"))
		{
			ToggleInaccuracy(param1);
		}
		else if (StrEqual(info, "Spread"))
		{
			ToggleSpread(param1);
		}
		else if (StrEqual(info, "Recoil"))
		{
			ToggleRecoil(param1);
		}
		else if (StrEqual(info, "Seed"))
		{
			ToggleSeed(param1);
		}
		else if (StrEqual(info, "Ammo"))
		{
			ToggleAmmo(param1);
		}
		Menu_TrueStrike(param1);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

// ====================
// Cookie
// ====================
void RegisterCookies()
{
	gH_TrueStrikeCookie = RegClientCookie("TrueStrike-cookie", "Main cookie for TrueStrike", CookieAccess_Private);
	gH_AmmoCookie = RegClientCookie("TrueStrikeAmmo-cookie", "Ammo cookie for TrueStrike", CookieAccess_Private);
	gH_InaccuracyCookie = RegClientCookie("TrueStrikeInaccuracy-cookie", "Inaccuracy cookie for TrueStrike", CookieAccess_Private);
	gH_RecoilCookie = RegClientCookie("TrueStrikeRecoil-cookie", "Recoil cookie for TrueStrike", CookieAccess_Private);
	gH_SeedCookie = RegClientCookie("TrueStrikeSeed-cookie", "Seed cookie for TrueStrike", CookieAccess_Private);
	gH_SpreadCookie = RegClientCookie("TrueStrikeSpread-cookie", "Spread cookie for TrueStrike", CookieAccess_Private);
}

int LoadCookie(int client, Handle cookie)
{
	char buffer[2];
	GetClientCookie(client, cookie, buffer, sizeof(buffer));
	return StringToInt(buffer);
}

void SetCookie(int client, Handle cookie, int variable)
{
	if (!AreClientCookiesCached(client))
	{
		return;
	}

	char buffer[2];
	IntToString(variable, buffer, sizeof(buffer));
	SetClientCookie(client, cookie, buffer);
}