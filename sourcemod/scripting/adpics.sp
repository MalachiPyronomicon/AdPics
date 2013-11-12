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
// * 2013-11-08	-	1.1.3		-	Merge Dr. Nick's client test/minor cleanup, reset interval/frequency on disconnect, fix convar name for version, add donator test so we aren't tied to donator plugin
// * 2013-11-11	-	1.1.4		-	Prevent spies from triggering ad (eventually detect dead ringer)
//	------------------------------------------------------------------------------------

#pragma semicolon 1

// INCLUDES
#include <sourcemod>
#include <smlib>							// Client_IsIngame, Client_SetScreenOverlay
#include <donator>							// IsPlayerDonator, OnPostDonatorCheck
#include <tf2_stocks>						// TF2_IsPlayerInCondition

// DEFINES
#define PLUGIN_VERSION			"1.1.4"
#define PLUGIN_PRINT_NAME		"[AdPics]"					// Used for self-identification in chat/logging
#define PATH_CFG_FILE			"configs/adpics.txt"		// This is where the overlays are called out

// GLOBALS
new Handle:g_hOverlayFrequency;				// Handle - Convar to set how often we show a client ads 
new g_iOverlayFrequency;					// How often we show a client ads 
new g_iOverlayAdsNum;						// Total Number of ads
new String:g_sOverlayPaths[256][256];		// Overlays Paths
new bool:g_bShowAd[MAXPLAYERS+1];			// Do we show ads to a client
new g_iAdRotation[MAXPLAYERS+1];			// Where are we in the ad rotation
new g_iAdInterval[MAXPLAYERS+1];			// Where are we in a client's ad interval
new bool:g_bUseDonators = false;			// Are we using the donator functionality


public Plugin:myinfo = {
	name = "AdPics",
	author = "Malachi",
	description = "Show graphics advertisments while player is dead or spectating",
	version = PLUGIN_VERSION,
	url = "TBD"
};


public OnPluginStart()
{
	// Opens adpics.txt and reads overlays paths
	decl String:path[PLATFORM_MAX_PATH],String:line[256];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, PATH_CFG_FILE);
	
	// Opens addons/sourcemod/configs/adpics.txt as read-only
	new Handle:fileHandle=OpenFile(path,"r"); 
	
	// READING
	while( !IsEndOfFile(fileHandle) && ReadFileLine(fileHandle, line, sizeof(line)) )
	{
		TrimString(line);
		g_sOverlayPaths[g_iOverlayAdsNum] = line;
		g_iOverlayAdsNum++;
	}
	CloseHandle(fileHandle);
	// END READING
	
	PrintToServer("%s Found %d ads.", PLUGIN_PRINT_NAME, g_iOverlayAdsNum);
	
	// Convars
	CreateConVar("sm_adpics", PLUGIN_VERSION, "Version of AdPics plugin", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_hOverlayFrequency = CreateConVar("sm_adpics_frequency", "5", "Show ads every Nth death.");
	
	// Exec Config
	AutoExecConfig(true);
	
	// Event Hooks
	HookEventEx("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEventEx("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
	g_iOverlayFrequency = GetConVarInt(g_hOverlayFrequency);
}


// Required: Basic donator interface
public OnAllPluginsLoaded()
{
	if(LibraryExists("donator.core"))
	{
		g_bUseDonators = true;
		PrintToServer("%s Found plugin: Basic Donator Interface", PLUGIN_PRINT_NAME);
	}
	else
	{
		g_bUseDonators = false;
		PrintToServer("%s Unable to find plugin: Basic Donator Interface", PLUGIN_PRINT_NAME);
		LogError("%s Unable to find plugin: Basic Donator Interface", PLUGIN_PRINT_NAME);
	}
}


// Don't show ads to donators
public OnPostDonatorCheck(iClient)
{
	if (IsPlayerDonator(iClient))
	{
		g_bShowAd[iClient] = false;
	}
	else
	{
		g_bShowAd[iClient] = true;
	}
	
	g_iAdInterval[iClient] = 0;
	g_iAdRotation[iClient] = 0;

	return;
}


public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	OverlayClean( GetClientOfUserId( GetEventInt(event, "userid") ) );
}
	
	
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	// Did client leave game?
	if (iClient == 0)
		return;
	
	// Don't show to donators
//	if (g_bUseDonators)
//		if (!g_bShowAd[iClient])
//			return;
	
	// Weed out dead ringer - temp weed out spies
	if (TF2_GetPlayerClass(iClient) == TFClass_Spy)
		return;

	// Whats our skip count?
	if (!g_iAdInterval[iClient])
	{
		OverlaySet(iClient, g_sOverlayPaths[g_iAdRotation[iClient]]);
		
		// Bump the rotation now that we've shown an ad
		g_iAdRotation[iClient] = (g_iAdRotation[iClient] + 1) % g_iOverlayAdsNum;
	}

	// Bump the interval
	g_iAdInterval[iClient] = (g_iAdInterval[iClient] + 1) % g_iOverlayFrequency;
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
	
	for (new i = 0; i < g_iOverlayAdsNum; i++)
	{
		// Adds overlays to downloads table and prechaches them
		Format(vtf, sizeof(vtf), "materials/%s.vtf", g_sOverlayPaths[i]);
		Format(vmt, sizeof(vmt), "materials/%s.vmt", g_sOverlayPaths[i]);
		AddFileToDownloadsTable(vtf);
		AddFileToDownloadsTable(vmt);
		PrecacheDecal(vtf, true);
		PrintToServer("%s %d) %s", PLUGIN_PRINT_NAME, i, vtf);
		
		// We only monitor this on map change
		g_iOverlayFrequency = GetConVarInt(g_hOverlayFrequency);
		
		// Test the cvar min value
		if (g_iOverlayFrequency < 1)
			g_iOverlayFrequency = 1;
	}
}
