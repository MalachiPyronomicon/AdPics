//	------------------------------------------------------------------------------------
//	Filename:		adpics.sp
//	Author:			Malachi (with help from Animalnots adsoverlays.sp v0.1)
//	Version:		(see PLUGIN_VERSION)
//	Description:	Show advertisments via overlays while player is dead or spectating.
//
// * Changelog (date/version/description):
// * 2013-11-04	-	0.1			-	initial fork from Animalnots adsoverlays.sp v0.1
// * 2013-11-06	-	0.1.1		-	Remove debug, tidy/unify code, use PLUGIN_VERSION for ver. cvar, remove timers, remove translations, remove colors, remove admin immunity/vip flag, 
//	------------------------------------------------------------------------------------

#pragma semicolon 1

// INCLUDES
#include <sourcemod>
#include <smlib>							// Client_IsIngame, Client_IsValid, Client_SetScreenOverlay
#include <donator>							// IsPlayerDonator, OnPostDonatorCheck

// DEFINES
#define PLUGIN_VERSION			"1.1.1"
#define PLUGIN_PRINT_NAME		"[AdPics]"			// Used for self-identification in chat/logging
#define PATH_CFG_FILE			"configs/adpics.txt"

// GLOBALS
new Handle:g_hOverlayFrequency;				// Handle - Convar for how often we show a client ads 
new g_dOverlayAdsNum = 0;					// Total Number of ads
new String:g_sOverlayPaths[256][256];		// Overlays Paths
new bool:g_ShowAd[MAXPLAYERS+1];			// Do we show ads to a client
new g_AdRotation[MAXPLAYERS+1];				// Where are we in the ad rotation
new g_AdInterval[MAXPLAYERS+1];				// Where are we in a client's ad interval


public Plugin:myinfo = {
	name = "AdsOverlays",
	author = "Malachi",
	description = "Show advertisments via overlays while player is dead or spectating",
	version = PLUGIN_VERSION,
	url = "TBD"
};


public OnPluginStart()
{
	// Opens ads.txt and reads overlays paths
	decl String:path[PLATFORM_MAX_PATH],String:line[256];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, PATH_CFG_FILE);
	
	// Opens addons/sourcemod/configs/ads.txt to read from (and only reading)
	new Handle:fileHandle=OpenFile(path,"r"); 
	
	// READING
	while( !IsEndOfFile(fileHandle) && ReadFileLine(fileHandle, line, sizeof(line)) )
	{
		TrimString(line);
		g_sOverlayPaths[g_dOverlayAdsNum] = line;
		g_dOverlayAdsNum++;
	}
	CloseHandle(fileHandle);
	// END READING
	
	PrintToServer("%s Found %d ads.", PLUGIN_PRINT_NAME, g_dOverlayAdsNum);
	LogAction(-1, -1, "%s Found %d ads.", PLUGIN_PRINT_NAME, g_dOverlayAdsNum);
	
	
	// Convars
	CreateConVar("sm_adsoverlays", PLUGIN_VERSION, "Version of AdsOverlay plugin", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_hOverlayFrequency = CreateConVar("sm_adsoverlays_frequency", "5.0", "Show ads every Nth death.");
	
	// Exec Config
	AutoExecConfig(true);
	
	// Event Hooks
	HookEventEx("player_death", event_player_death, EventHookMode_Post);
	HookEventEx("player_spawn", event_player_spawn, EventHookMode_Post);
}


// Don't show ads to donators
public OnPostDonatorCheck(iClient)
{
	if (IsPlayerDonator(iClient))
	{
		g_ShowAd[iClient] = false;
	}
	else
	{
		g_ShowAd[iClient] = true;
	}
	
	return;
}


// Cleanup on disconnect
public OnClientDisconnect(iClient)
{
	g_ShowAd[iClient] = true;
}


public Action:event_player_spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	OverlayClean( GetClientOfUserId( GetEventInt(event, "userid") ) );
}
	
	
public Action:event_player_death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
	OverlaySet(iClient, g_sOverlayPaths[0]);
}
	
	
// Clear a client's Overlay
public OverlayClean(iClient)
{
	
	if(Client_IsIngame(iClient) && Client_IsValid(iClient))
	{
		Client_SetScreenOverlay(iClient, "off");
		Client_SetScreenOverlay(iClient, "");			
	}
}


stock OverlaySet(any:iClient, String:overlay[])
{
	if(Client_IsIngame(iClient) && Client_IsValid(iClient))
	{
		Client_SetScreenOverlay(iClient, overlay);
	}
}


public OnMapStart()
{
	decl String:vmt[PLATFORM_MAX_PATH];
	decl String:vtf[PLATFORM_MAX_PATH];
	
	for (new i = 0; i < g_dOverlayAdsNum; i++)
	{
		// Adds overlays to downloads table and prechaches them
		Format(vtf, sizeof(vtf), "materials/%s.vtf", g_sOverlayPaths[i]);
		Format(vmt, sizeof(vmt), "materials/%s.vmt", g_sOverlayPaths[i]);
		AddFileToDownloadsTable(vtf);
		AddFileToDownloadsTable(vmt);
		PrecacheDecal(vtf, true);
		PrintToServer("%d) %s", i, vtf);
		LogAction(-1, -1, "%d) %s", i, vtf);
		
	}
}