//	------------------------------------------------------------------------------------
//	Filename:		adpics.sp
//	Author:			Malachi (with help from Animalnots adsoverlays.sp v0.1)
//	Version:		(see PLUGIN_VERSION)
//	Description:	Show advertisments via overlays while player is dead or spectating.
//
// * Changelog (date/version/description):
// * 2013-11-04	-	0.1			-	initial fork from Animalnots adsoverlays.sp v0.1
// * 2013-11-06	-	1.1.1		-	Remove debug, tidy/unify code, use PLUGIN_VERSION for ver. cvar, remove timers, remove translations, remove colors, remove admin immunity/vip flag, 
// * 2013-11-06	-	1.1.2		-	add tests for interval/frequency 
//	------------------------------------------------------------------------------------

#pragma semicolon 1

// INCLUDES
#include <sourcemod>
#include <smlib>							// Client_IsIngame, Client_IsValid, Client_SetScreenOverlay
#include <donator>							// IsPlayerDonator, OnPostDonatorCheck

// DEFINES
#define PLUGIN_VERSION			"1.1.2"
#define PLUGIN_PRINT_NAME		"[AdPics]"					// Used for self-identification in chat/logging
#define PATH_CFG_FILE			"configs/adpics.txt"		// This is where the overlays are called out

// GLOBALS
new Handle:g_hOverlayFrequency;				// Handle - Convar to set how often we show a client ads 
new g_OverlayFrequency;						// How often we show a client ads 
new g_dOverlayAdsNum;						// Total Number of ads
new String:g_sOverlayPaths[256][256];		// Overlays Paths
new bool:g_ShowAd[MAXPLAYERS+1];			// Do we show ads to a client
new g_AdRotation[MAXPLAYERS+1];				// Where are we in the ad rotation
new g_AdInterval[MAXPLAYERS+1];				// Where are we in a client's ad interval


public Plugin:myinfo = {
	name = "AdPics",
	author = "Malachi",
	description = "Show advertisments via overlays while player is dead or spectating",
	version = PLUGIN_VERSION,
	url = "TBD"
};


public OnPluginStart()
{
	// Opens adpics.txt and reads overlays paths
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
//	LogAction(-1, -1, "%s Found %d ads.", PLUGIN_PRINT_NAME, g_dOverlayAdsNum);
	
	
	// Convars
	CreateConVar("sm_adsoverlays", PLUGIN_VERSION, "Version of AdsOverlay plugin", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_hOverlayFrequency = CreateConVar("sm_adpics_frequency", "5", "Show ads every Nth death.");
	
	// Exec Config
	AutoExecConfig(true);
	
	// Event Hooks
	HookEventEx("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEventEx("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
	g_OverlayFrequency = GetConVarInt(g_hOverlayFrequency);
}


// Required: Basic donator interface
public OnAllPluginsLoaded()
{
	if(!LibraryExists("donator.core"))
		SetFailState("%s Unable to find plugin: Basic Donator Interface", PLUGIN_PRINT_NAME);
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


public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	OverlayClean( GetClientOfUserId( GetEventInt(event, "userid") ) );
}
	
	
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	if (iClient == 0)
	{
		//Client left game
		return;
	}
	
	// Don't show to donators
//	if (!g_ShowAd[iClient])
//		return;
	
	// Bump the interval
	g_AdInterval[iClient] = g_AdInterval[iClient] + 1;

		// Whats our skip count?
	if (g_AdInterval[iClient] >= g_OverlayFrequency)
	{
		OverlaySet(iClient, g_sOverlayPaths[g_AdRotation[iClient]]);
		
		// Bump the rotation now that we've shown an ad
		g_AdRotation[iClient] = (g_AdRotation[iClient] + 1) % g_dOverlayAdsNum;
		
		// Reset the interval now that we've shown an ad
		g_AdInterval[iClient] = 0;
	}
	
}
	
	
// Clear a client's Overlay
public OverlayClean(iClient)
{
	
	if(Client_IsIngame(iClient))
	{
		Client_SetScreenOverlay(iClient, "off");
		Client_SetScreenOverlay(iClient, "");			
	}
}


stock OverlaySet(any:iClient, String:overlay[])
{
	if(Client_IsIngame(iClient))
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
		PrintToServer("%s %d) %s", PLUGIN_PRINT_NAME, i, vtf);
//		LogAction(-1, -1, "%s %d) %s", PLUGIN_PRINT_NAME, i, vtf);
		
		// We only monitor this on map change
		g_OverlayFrequency = GetConVarInt(g_hOverlayFrequency);
	}
}
