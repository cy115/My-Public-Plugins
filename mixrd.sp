#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <sdktools>
#include <left4dhooks>
#include <readyup>

bool
    g_bIsSwapPlayersReady = false;

ArrayList
    AllPlayers;

public Plugin myinfo =
{
    name = "mixrd",
    author = "Hitomi",
    description = "88随机分队",
    version = "1.0",
    url = "https://github.com/cy115/"
};

public void OnPluginStart()
{
    AllPlayers = new ArrayList(ByteCountToCells(64));
}

public void OnReadyUpInitiate()
{
    CreateTimer(1.0, Timer_CheckClientAllInGame, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidSurvivor(i) || IsValidInfected(i)) {
            ChangeClientTeam(i, 1);
        }
    }
}

Action Timer_CheckClientAllInGame(Handle timer)
{
    bool bIsPlayerConnecting = ProcessPlayers();
    if (!bIsPlayerConnecting && g_bIsSwapPlayersReady) {
        for (int i = 0; i < AllPlayers.Length; i++) {
            int client = AllPlayers.Get(i);
            ChangeClientTeam(client, (i % 2 == 1) ? 3 : 2);
        }

        g_bIsSwapPlayersReady = false;
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

public void OnMapStart()
{
    ReadyToStartMixRandom();
}

void ReadyToStartMixRandom()
{
    int num = AllPlayers.Length, time = 0;
    if (num > 1) {
        while (time < 8) {
            AllPlayers.SwapAt(GetRandomInt(0, num), GetRandomInt(0, num));
            time++;
        }

        g_bIsSwapPlayersReady = true;
    }
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
    if (InSecondHalfOfRound()) {
        AllPlayers.Clear();
        for (int i = 1; i <= MaxClients; i++) {
            if (IsValidSurvivor(i) || IsValidInfected(i)) {
                AllPlayers.Push(i);
            }
        } 
    }

    return Plugin_Continue;
}

// Tools
stock bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

stock bool IsValidSurvivor(int client)
{
    return IsValidClient(client) && GetClientTeam(client) == 2;
}

stock bool IsValidInfected(int client)
{
    return IsValidClient(client) && GetClientTeam(client) == 3;
}

stock bool ProcessPlayers()
{
    int iConnectedCount = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) {
            if (IsClientConnected(i))
                iConnectedCount++;
        }
    }

    return iConnectedCount > 0;
}

stock bool InSecondHalfOfRound()
{
    return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}
